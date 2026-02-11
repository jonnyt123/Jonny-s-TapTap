import "dotenv/config";
import express from "express";
import cors from "cors";
import http from "http";
import { InMemoryLobbyStore } from "./store.js";
import { buildRoutes } from "./routes.js";
import { setupWebSocketServer } from "./ws.js";
import { verifySessionToken } from "./auth.js";

const app = express();
const server = http.createServer(app);

const config = {
  port: Number(process.env.PORT) || 8080,
  jwtSecret: process.env.JWT_SECRET || "dev-secret",
  appleClientId: process.env.APPLE_CLIENT_ID || "com.jonnystaptap.rhythmtap",
  bundleId: process.env.BUNDLE_ID || "com.jonnystaptap.rhythmtap",
  corsOrigins: (process.env.CORS_ORIGINS || "*").split(",")
};

const store = new InMemoryLobbyStore();

app.use(express.json({ limit: "1mb" }));
app.use(cors({ origin: config.corsOrigins, credentials: false }));

app.use((req, _res, next) => {
  const authHeader = req.headers.authorization || "";
  if (authHeader.startsWith("Bearer ")) {
    const token = authHeader.slice("Bearer ".length);
    try {
      req.auth = verifySessionToken(token, config);
    } catch {
      req.auth = undefined;
    }
  }
  next();
});

const { broadcastLobby } = setupWebSocketServer({
  server,
  store,
  jwtSecret: config.jwtSecret
});

app.use("/", buildRoutes({
  store,
  config,
  broadcastLobby
}));

server.listen(config.port, "0.0.0.0", () => {
  console.log(`Multiplayer server listening on 0.0.0.0:${config.port}`);
});
