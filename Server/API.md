# Jonny's TapTap Multiplayer API

Base URL: `https://<your-host>`
WebSocket: `wss://<your-host>/ws?token=<JWT>`

## Auth
### POST /auth/apple
Body:
```json
{ "identityToken": "<apple_jwt>" }
```
Response:
```json
{ "token": "<jwt>", "session": { "userId": "...", "displayName": "...", "provider": "apple" } }
```

### POST /auth/gamecenter
Body:
```json
{
  "playerID": "...",
  "bundleID": "com.jonnystaptap.rhythmtap",
  "publicKeyUrl": "https://...",
  "signature": "<base64>",
  "salt": "<base64>",
  "timestamp": "<string>",
  "displayName": "Optional"
}
```
Response: same as `/auth/apple`.

## Lobbies
### GET /lobbies
Response:
```json
{ "lobbies": [ { "id": "...", "name": "...", "isPrivate": false, "maxPlayers": 4, "currentPlayers": 2, "hostName": "...", "trackId": "...", "difficulty": "medium", "status": "open" } ] }
```

### POST /lobbies (auth required)
Body:
```json
{ "name": "Metal Room", "isPrivate": false, "maxPlayers": 4, "trackId": "holiday", "difficulty": "hard", "password": "" }
```
Response: `{ "lobby": <Lobby> }`

### GET /lobbies/:id
Response: `{ "lobby": <Lobby> }`

### POST /lobbies/:id/join (auth required)
Body: `{ "password": "" }`
Response: `{ "lobby": <Lobby> }`

### POST /lobbies/:id/leave (auth required)
Response: `{ "lobby": <Lobby> }`

### POST /lobbies/:id/ready (auth required)
### POST /lobbies/:id/unready (auth required)
Response: `{ "lobby": <Lobby> }`

### POST /lobbies/:id/track (host only)
Body: `{ "trackId": "...", "difficulty": "easy" }`
Response: `{ "lobby": <Lobby> }`

### POST /lobbies/:id/start (host only)
Response: `{ "lobby": <Lobby> }` with `startAt` set (epoch ms).

## Leaderboards
### POST /leaderboards/submit (auth required)
Body:
```json
{ "score": 12345, "accuracy": 98.5, "maxCombo": 400, "trackId": "holiday", "difficulty": "hard" }
```
Response: `{ "ok": true }`

### GET /leaderboards/global?limit=50
### GET /leaderboards/track/:trackId?difficulty=hard&limit=50

## WebSocket Messages
### Client -> Server
- `lobby:subscribe` `{ "lobbyId": "..." }`
- `lobby:chat` `{ "lobbyId": "...", "text": "..." }`
- `lobby:ready` `{ "lobbyId": "...", "ready": true }`
- `lobby:start` `{ "lobbyId": "..." }`
- `timeSyncPing` `{ "clientTime": 1700000000000 }`

### Server -> Client
- `hello` `{ "userId": "...", "displayName": "..." }`
- `timeSync` `{ "serverTime": 1700000000000 }`
- `timeSyncPong` `{ "clientTime": 1700000000000, "serverTime": 1700000000005 }`
- `lobby:update` `<Lobby>`
- `error` `{ "message": "..." }`

## Lobby Object
```json
{
  "id": "...",
  "name": "...",
  "isPrivate": false,
  "maxPlayers": 4,
  "hostId": "...",
  "createdAt": 1700000000000,
  "updatedAt": 1700000000000,
  "track": { "trackId": "holiday", "difficulty": "hard" },
  "members": [ { "userId": "...", "displayName": "...", "isHost": true, "isReady": false, "joinedAt": 1700000000000 } ],
  "chat": [ { "id": "...", "userId": "...", "displayName": "...", "message": "...", "createdAt": 1700000000000 } ],
  "status": "open",
  "startAt": 1700000003000
}
```
