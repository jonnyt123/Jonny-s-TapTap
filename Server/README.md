# Multiplayer Server

## Quick Start (Local)
```bash
npm install
npm run dev
```

## Env Vars
```
PORT=8080
JWT_SECRET=replace-me
APPLE_CLIENT_ID=com.jonnystaptap.rhythmtap
BUNDLE_ID=com.jonnystaptap.rhythmtap
CORS_ORIGINS=*
```

## Docker
```bash
docker build -t taptap-multiplayer .
docker run -p 8080:8080 -e JWT_SECRET=replace-me taptap-multiplayer
```

## Railway
- Connect this folder as a Railway service.
- Add the env vars above.
- Deploy. WebSockets supported on Railway.

## Vercel
- Vercel can host REST endpoints, but WebSockets are not supported reliably.
- Use Railway for full lobby + chat.

See `API.md` for endpoints and WebSocket messages.
