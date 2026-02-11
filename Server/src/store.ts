import { Lobby, LobbyMember, LobbySummary, TrackSelection, Difficulty, LeaderboardEntry } from "./types.js";
import { randomUUID } from "crypto";

export interface LobbyStore {
  listLobbies(): LobbySummary[];
  getLobby(id: string): Lobby | undefined;
  createLobby(params: {
    name: string;
    isPrivate: boolean;
    maxPlayers: number;
    host: LobbyMember;
    track: TrackSelection;
    passwordHash?: string;
  }): Lobby;
  updateLobby(id: string, patch: Partial<Lobby>): Lobby | undefined;
  deleteLobby(id: string): void;
  addMember(id: string, member: LobbyMember): Lobby | undefined;
  removeMember(id: string, userId: string): Lobby | undefined;
  setReady(id: string, userId: string, isReady: boolean): Lobby | undefined;
  updateTrack(id: string, track: TrackSelection): Lobby | undefined;
  addChatMessage(id: string, message: Lobby["chat"][0]): Lobby | undefined;
  setStartAt(id: string, startAt: number): Lobby | undefined;
  setStatus(id: string, status: Lobby["status"]): Lobby | undefined;

  submitScore(entry: LeaderboardEntry): void;
  getLeaderboardGlobal(limit: number): LeaderboardEntry[];
  getLeaderboardTrack(trackId: string, difficulty?: Difficulty, limit?: number): LeaderboardEntry[];
}

export class InMemoryLobbyStore implements LobbyStore {
  private lobbies = new Map<string, Lobby>();
  private leaderboards: LeaderboardEntry[] = [];

  listLobbies(): LobbySummary[] {
    return Array.from(this.lobbies.values()).map((lobby) => ({
      id: lobby.id,
      name: lobby.name,
      isPrivate: lobby.isPrivate,
      maxPlayers: lobby.maxPlayers,
      currentPlayers: lobby.members.length,
      hostName: lobby.members.find((m) => m.isHost)?.displayName ?? "Host",
      trackId: lobby.track.trackId,
      difficulty: lobby.track.difficulty,
      status: lobby.status
    }));
  }

  getLobby(id: string): Lobby | undefined {
    return this.lobbies.get(id);
  }

  createLobby(params: {
    name: string;
    isPrivate: boolean;
    maxPlayers: number;
    host: LobbyMember;
    track: TrackSelection;
    passwordHash?: string;
  }): Lobby {
    const id = randomUUID();
    const now = Date.now();
    const lobby: Lobby = {
      id,
      name: params.name,
      isPrivate: params.isPrivate,
      passwordHash: params.passwordHash,
      maxPlayers: params.maxPlayers,
      hostId: params.host.userId,
      createdAt: now,
      updatedAt: now,
      track: params.track,
      members: [params.host],
      chat: [],
      status: "open"
    };
    this.lobbies.set(id, lobby);
    return lobby;
  }

  updateLobby(id: string, patch: Partial<Lobby>): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    const updated = { ...lobby, ...patch, updatedAt: Date.now() } as Lobby;
    this.lobbies.set(id, updated);
    return updated;
  }

  deleteLobby(id: string): void {
    this.lobbies.delete(id);
  }

  addMember(id: string, member: LobbyMember): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    if (lobby.members.find((m) => m.userId === member.userId)) {
      return lobby;
    }
    lobby.members.push(member);
    lobby.updatedAt = Date.now();
    this.lobbies.set(id, lobby);
    return lobby;
  }

  removeMember(id: string, userId: string): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    lobby.members = lobby.members.filter((m) => m.userId !== userId);
    lobby.updatedAt = Date.now();
    this.lobbies.set(id, lobby);
    return lobby;
  }

  setReady(id: string, userId: string, isReady: boolean): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    lobby.members = lobby.members.map((m) =>
      m.userId == userId ? { ...m, isReady } : m
    );
    lobby.updatedAt = Date.now();
    this.lobbies.set(id, lobby);
    return lobby;
  }

  updateTrack(id: string, track: TrackSelection): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    lobby.track = track;
    lobby.updatedAt = Date.now();
    this.lobbies.set(id, lobby);
    return lobby;
  }

  addChatMessage(id: string, message: Lobby["chat"][0]): Lobby | undefined {
    const lobby = this.lobbies.get(id);
    if (!lobby) return undefined;
    lobby.chat.push(message);
    if (lobby.chat.length > 100) {
      lobby.chat.shift();
    }
    lobby.updatedAt = Date.now();
    this.lobbies.set(id, lobby);
    return lobby;
  }

  setStartAt(id: string, startAt: number): Lobby | undefined {
    return this.updateLobby(id, { startAt, status: "starting" });
  }

  setStatus(id: string, status: Lobby["status"]): Lobby | undefined {
    return this.updateLobby(id, { status });
  }

  submitScore(entry: LeaderboardEntry): void {
    this.leaderboards.push(entry);
    if (this.leaderboards.length > 2000) {
      this.leaderboards.shift();
    }
  }

  getLeaderboardGlobal(limit: number): LeaderboardEntry[] {
    return this.leaderboards
      .slice()
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }

  getLeaderboardTrack(trackId: string, difficulty?: Difficulty, limit: number = 50): LeaderboardEntry[] {
    return this.leaderboards
      .filter((entry) => entry.trackId === trackId && (!difficulty || entry.difficulty === difficulty))
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }
}
