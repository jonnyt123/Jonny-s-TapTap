export type Difficulty = "easy" | "medium" | "hard" | "extreme";

export type AuthProvider = "apple" | "gamecenter";

export interface AuthSession {
  userId: string;
  displayName: string;
  provider: AuthProvider;
}

export interface LobbyMember {
  userId: string;
  displayName: string;
  isHost: boolean;
  isReady: boolean;
  joinedAt: number;
}

export interface TrackSelection {
  trackId: string;
  difficulty: Difficulty;
  bpm?: number;
}

export interface Lobby {
  id: string;
  name: string;
  isPrivate: boolean;
  passwordHash?: string;
  maxPlayers: number;
  hostId: string;
  createdAt: number;
  updatedAt: number;
  track: TrackSelection;
  members: LobbyMember[];
  chat: ChatMessage[];
  status: "open" | "starting" | "in-game";
  startAt?: number;
}

export interface ChatMessage {
  id: string;
  userId: string;
  displayName: string;
  message: string;
  createdAt: number;
}

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  score: number;
  accuracy: number;
  maxCombo: number;
  trackId: string;
  difficulty: Difficulty;
  createdAt: number;
}

export interface LobbySummary {
  id: string;
  name: string;
  isPrivate: boolean;
  maxPlayers: number;
  currentPlayers: number;
  hostName: string;
  trackId: string;
  difficulty: Difficulty;
  status: Lobby["status"];
}

export interface ServerConfig {
  port: number;
  jwtSecret: string;
  appleClientId: string;
  bundleId: string;
  corsOrigins: string[];
}

export interface WsMessage {
  type: string;
  payload?: unknown;
}
