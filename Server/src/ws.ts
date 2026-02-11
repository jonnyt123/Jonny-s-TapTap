import { WebSocketServer, WebSocket } from "ws";
import { LobbyStore } from "./store.js";
import { verifySessionToken } from "./auth.js";
import { AuthSession, WsMessage } from "./types.js";
import { randomUUID } from "crypto";

interface ClientContext {
  session: AuthSession;
  lobbyId?: string;
}

export function setupWebSocketServer(options: {
  server: import("http").Server;
  store: LobbyStore;
  jwtSecret: string;
}) {
  const wss = new WebSocketServer({ server: options.server, path: "/ws" });
  const clients = new Map<WebSocket, ClientContext>();

  function send(ws: WebSocket, message: WsMessage) {
    ws.send(JSON.stringify(message));
  }

  function broadcastLobby(lobbyId: string) {
    const lobby = options.store.getLobby(lobbyId);
    if (!lobby) return;
    const message: WsMessage = { type: "lobby:update", payload: lobby };
    for (const [ws, ctx] of clients.entries()) {
      if (ctx.lobbyId === lobbyId) {
        send(ws, message);
      }
    }
  }

  wss.on("connection", (ws, req) => {
    const url = new URL(req.url ?? "", "http://localhost");
    const token = url.searchParams.get("token");
    if (!token) {
      ws.close(4001, "Missing token");
      return;
    }

    let session: AuthSession;
    try {
      session = verifySessionToken(token, {
        port: 0,
        jwtSecret: options.jwtSecret,
        appleClientId: "",
        bundleId: "",
        corsOrigins: []
      });
    } catch {
      ws.close(4002, "Invalid token");
      return;
    }

    clients.set(ws, { session });
    send(ws, { type: "hello", payload: { userId: session.userId, displayName: session.displayName } });
    send(ws, { type: "timeSync", payload: { serverTime: Date.now() } });

    ws.on("message", (data) => {
      try {
        const message = JSON.parse(data.toString()) as WsMessage;
        handleMessage(ws, message);
      } catch {
        send(ws, { type: "error", payload: { message: "Invalid JSON" } });
      }
    });

    ws.on("close", () => {
      const ctx = clients.get(ws);
      if (ctx?.lobbyId) {
        options.store.removeMember(ctx.lobbyId, ctx.session.userId);
        broadcastLobby(ctx.lobbyId);
      }
      clients.delete(ws);
    });
  });

  function handleMessage(ws: WebSocket, message: WsMessage) {
    const ctx = clients.get(ws);
    if (!ctx) return;

    switch (message.type) {
      case "lobby:subscribe": {
        const { lobbyId } = message.payload as { lobbyId: string };
        const lobby = options.store.getLobby(lobbyId);
        if (!lobby) {
          send(ws, { type: "error", payload: { message: "Lobby not found" } });
          return;
        }
        ctx.lobbyId = lobbyId;
        send(ws, { type: "lobby:update", payload: lobby });
        return;
      }
      case "lobby:chat": {
        const { lobbyId, text } = message.payload as { lobbyId: string; text: string };
        const lobby = options.store.getLobby(lobbyId);
        if (!lobby) return;
        const chatMessage = {
          id: randomUUID(),
          userId: ctx.session.userId,
          displayName: ctx.session.displayName,
          message: text.slice(0, 200),
          createdAt: Date.now()
        };
        options.store.addChatMessage(lobbyId, chatMessage);
        broadcastLobby(lobbyId);
        return;
      }
      case "lobby:ready": {
        const { lobbyId, ready } = message.payload as { lobbyId: string; ready: boolean };
        options.store.setReady(lobbyId, ctx.session.userId, ready);
        broadcastLobby(lobbyId);
        return;
      }
      case "lobby:start": {
        const { lobbyId } = message.payload as { lobbyId: string };
        const lobby = options.store.getLobby(lobbyId);
        if (!lobby || lobby.hostId !== ctx.session.userId) return;
        const allReady = lobby.members.every((member) => member.isReady || member.userId === lobby.hostId);
        if (!allReady) {
          send(ws, { type: "error", payload: { message: "Not all players ready" } });
          return;
        }
        const startAt = Date.now() + 3000;
        options.store.setStartAt(lobbyId, startAt);
        broadcastLobby(lobbyId);
        return;
      }
      case "timeSyncPing": {
        const { clientTime } = message.payload as { clientTime: number };
        send(ws, { type: "timeSyncPong", payload: { clientTime, serverTime: Date.now() } });
        return;
      }
      default:
        send(ws, { type: "error", payload: { message: "Unknown message type" } });
    }
  }

  return { wss, broadcastLobby };
}
