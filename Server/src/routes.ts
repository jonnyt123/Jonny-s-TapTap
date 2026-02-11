import { Router } from "express";
import { LobbyStore } from "./store.js";
import { AuthSession, Difficulty, TrackSelection } from "./types.js";
import { issueSessionToken, verifyAppleIdentityToken, verifyGameCenterSignature } from "./auth.js";
import { randomUUID } from "crypto";

export function buildRoutes(options: {
  store: LobbyStore;
  config: { appleClientId: string; bundleId: string; jwtSecret: string };
  broadcastLobby: (lobbyId: string) => void;
}) {
  const router = Router();

  router.get("/health", (_, res) => res.json({ ok: true }));

  router.post("/auth/apple", async (req, res) => {
    const { identityToken } = req.body ?? {};
    if (!identityToken) {
      return res.status(400).json({ error: "Missing identityToken" });
    }
    try {
      const session = await verifyAppleIdentityToken(identityToken, {
        port: 0,
        jwtSecret: options.config.jwtSecret,
        appleClientId: options.config.appleClientId,
        bundleId: options.config.bundleId,
        corsOrigins: []
      });
      const token = issueSessionToken(session, {
        port: 0,
        jwtSecret: options.config.jwtSecret,
        appleClientId: options.config.appleClientId,
        bundleId: options.config.bundleId,
        corsOrigins: []
      });
      res.json({ token, session });
    } catch (error) {
      res.status(401).json({ error: "Apple auth failed" });
    }
  });

  router.post("/auth/gamecenter", async (req, res) => {
    const { playerID, bundleID, publicKeyUrl, signature, salt, timestamp, displayName } = req.body ?? {};
    if (!playerID || !bundleID || !publicKeyUrl || !signature || !salt || !timestamp) {
      return res.status(400).json({ error: "Missing Game Center payload" });
    }
    try {
      const session = await verifyGameCenterSignature(
        { playerID, bundleID, publicKeyUrl, signature, salt, timestamp, displayName },
        {
          port: 0,
          jwtSecret: options.config.jwtSecret,
          appleClientId: options.config.appleClientId,
          bundleId: options.config.bundleId,
          corsOrigins: []
        }
      );
      const token = issueSessionToken(session, {
        port: 0,
        jwtSecret: options.config.jwtSecret,
        appleClientId: options.config.appleClientId,
        bundleId: options.config.bundleId,
        corsOrigins: []
      });
      res.json({ token, session });
    } catch {
      res.status(401).json({ error: "Game Center auth failed" });
    }
  });

  router.get("/lobbies", (_, res) => {
    res.json({ lobbies: options.store.listLobbies() });
  });

  router.post("/lobbies", (req, res) => {
    const session = req.auth;
    if (!session) {
      return res.status(401).json({ error: "Unauthorized" });
    }
    const { name, isPrivate, maxPlayers, trackId, difficulty, password } = req.body ?? {};
    if (!name || !trackId || !difficulty) {
      return res.status(400).json({ error: "Missing lobby data" });
    }
    const track: TrackSelection = {
      trackId,
      difficulty: difficulty as Difficulty
    };
    const host = {
      userId: session.userId,
      displayName: session.displayName,
      isHost: true,
      isReady: false,
      joinedAt: Date.now()
    };
    const lobby = options.store.createLobby({
      name,
      isPrivate: Boolean(isPrivate),
      maxPlayers: Math.min(Math.max(Number(maxPlayers) || 4, 2), 8),
      host,
      track,
      passwordHash: password ? Buffer.from(password).toString("base64") : undefined
    });
    res.json({ lobby });
  });

  router.get("/lobbies/:id", (req, res) => {
    const lobby = options.store.getLobby(req.params.id);
    if (!lobby) return res.status(404).json({ error: "Not found" });
    res.json({ lobby });
  });

  router.post("/lobbies/:id/join", (req, res) => {
    const session = req.auth;
    if (!session) {
      return res.status(401).json({ error: "Unauthorized" });
    }
    const lobby = options.store.getLobby(req.params.id);
    if (!lobby) return res.status(404).json({ error: "Not found" });
    if (lobby.members.length >= lobby.maxPlayers) {
      return res.status(409).json({ error: "Lobby full" });
    }
    if (lobby.isPrivate) {
      const password = req.body?.password ?? "";
      const hash = Buffer.from(password).toString("base64");
      if (hash !== lobby.passwordHash) {
        return res.status(403).json({ error: "Invalid password" });
      }
    }
    const member = {
      userId: session.userId,
      displayName: session.displayName,
      isHost: lobby.hostId === session.userId,
      isReady: false,
      joinedAt: Date.now()
    };
    const updated = options.store.addMember(lobby.id, member);
    if (updated) {
      options.broadcastLobby(lobby.id);
    }
    res.json({ lobby: updated });
  });

  router.post("/lobbies/:id/leave", (req, res) => {
    const session = req.auth;
    if (!session) {
      return res.status(401).json({ error: "Unauthorized" });
    }
    const lobby = options.store.removeMember(req.params.id, session.userId);
    if (lobby) {
      options.broadcastLobby(req.params.id);
    }
    res.json({ lobby });
  });

  router.post("/lobbies/:id/ready", (req, res) => {
    const session = req.auth;
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const lobby = options.store.setReady(req.params.id, session.userId, true);
    if (lobby) {
      options.broadcastLobby(req.params.id);
    }
    res.json({ lobby });
  });

  router.post("/lobbies/:id/unready", (req, res) => {
    const session = req.auth;
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const lobby = options.store.setReady(req.params.id, session.userId, false);
    if (lobby) {
      options.broadcastLobby(req.params.id);
    }
    res.json({ lobby });
  });

  router.post("/lobbies/:id/track", (req, res) => {
    const session = req.auth;
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const lobby = options.store.getLobby(req.params.id);
    if (!lobby) return res.status(404).json({ error: "Not found" });
    if (lobby.hostId !== session.userId) {
      return res.status(403).json({ error: "Host only" });
    }
    const { trackId, difficulty } = req.body ?? {};
    if (!trackId || !difficulty) {
      return res.status(400).json({ error: "Missing track" });
    }
    const updated = options.store.updateTrack(req.params.id, {
      trackId,
      difficulty: difficulty as Difficulty
    });
    if (updated) {
      options.broadcastLobby(req.params.id);
    }
    res.json({ lobby: updated });
  });

  router.post("/lobbies/:id/start", (req, res) => {
    const session = req.auth;
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const lobby = options.store.getLobby(req.params.id);
    if (!lobby) return res.status(404).json({ error: "Not found" });
    if (lobby.hostId !== session.userId) {
      return res.status(403).json({ error: "Host only" });
    }
    const allReady = lobby.members.every((member) => member.isReady || member.userId === lobby.hostId);
    if (!allReady) {
      return res.status(409).json({ error: "Not all players ready" });
    }
    const startAt = Date.now() + 3000;
    const updated = options.store.setStartAt(req.params.id, startAt);
    if (updated) {
      options.broadcastLobby(req.params.id);
    }
    res.json({ lobby: updated });
  });

  router.post("/leaderboards/submit", (req, res) => {
    const session = req.auth;
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const { score, accuracy, maxCombo, trackId, difficulty } = req.body ?? {};
    if (!trackId || score == null || accuracy == null || maxCombo == null || !difficulty) {
      return res.status(400).json({ error: "Missing score data" });
    }
    options.store.submitScore({
      userId: session.userId,
      displayName: session.displayName,
      score: Number(score),
      accuracy: Number(accuracy),
      maxCombo: Number(maxCombo),
      trackId,
      difficulty: difficulty as Difficulty,
      createdAt: Date.now()
    });
    res.json({ ok: true });
  });

  router.get("/leaderboards/global", (req, res) => {
    const limit = Number(req.query.limit) || 50;
    res.json({ entries: options.store.getLeaderboardGlobal(limit) });
  });

  router.get("/leaderboards/track/:trackId", (req, res) => {
    const limit = Number(req.query.limit) || 50;
    const difficulty = req.query.difficulty as Difficulty | undefined;
    res.json({ entries: options.store.getLeaderboardTrack(req.params.trackId, difficulty, limit) });
  });

  return router;
}

declare module "express-serve-static-core" {
  interface Request {
    auth?: AuthSession;
  }
}
