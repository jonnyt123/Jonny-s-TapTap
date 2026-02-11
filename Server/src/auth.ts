import crypto from "crypto";
import jwt from "jsonwebtoken";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { AuthSession, ServerConfig } from "./types.js";

const appleJWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

export async function verifyAppleIdentityToken(identityToken: string, config: ServerConfig): Promise<AuthSession> {
  const { payload } = await jwtVerify(identityToken, appleJWKS, {
    issuer: "https://appleid.apple.com",
    audience: config.appleClientId
  });

  const userId = payload.sub;
  if (!userId) {
    throw new Error("Invalid Apple identity token");
  }
  const displayName = (payload.email as string | undefined) ?? "Player";
  return { userId, displayName, provider: "apple" };
}

export async function verifyGameCenterSignature(params: {
  playerID: string;
  bundleID: string;
  publicKeyUrl: string;
  signature: string;
  salt: string;
  timestamp: string;
  displayName?: string;
}, config: ServerConfig): Promise<AuthSession> {
  const { playerID, bundleID, publicKeyUrl, signature, salt, timestamp, displayName } = params;
  if (bundleID !== config.bundleId) {
    throw new Error("Bundle ID mismatch");
  }

  const publicKeyPem = await fetch(publicKeyUrl).then((res) => res.text());
  const data = Buffer.concat([
    Buffer.from(playerID, "utf8"),
    Buffer.from(bundleID, "utf8"),
    Buffer.from(timestamp, "utf8"),
    Buffer.from(salt, "base64")
  ]);

  const verifier = crypto.createVerify("RSA-SHA256");
  verifier.update(data);
  verifier.end();
  const valid = verifier.verify(publicKeyPem, Buffer.from(signature, "base64"));
  if (!valid) {
    throw new Error("Invalid Game Center signature");
  }

  return {
    userId: playerID,
    displayName: displayName ?? "Player",
    provider: "gamecenter"
  };
}

export function issueSessionToken(session: AuthSession, config: ServerConfig): string {
  return jwt.sign(session, config.jwtSecret, { expiresIn: "12h" });
}

export function verifySessionToken(token: string, config: ServerConfig): AuthSession {
  return jwt.verify(token, config.jwtSecret) as AuthSession;
}
