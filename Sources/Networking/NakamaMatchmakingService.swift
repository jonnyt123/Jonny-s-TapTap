//
//  NakamaMatchmakingService.swift
//  Jonny's Tap Tap
//
//  PURPOSE:
//  - Authenticate (device ID)
//  - Connect realtime socket
//  - Start/Cancel matchmaking
//  - Receive "match found" and optionally join the match
//
//  PHYSICAL DEVICES NOTE:
//  - You are running Nakama on your Mac at 192.168.2.75
//  - Phones must be on same Wi-Fi
//  - iOS may require ATS exception for http://192.168.2.75:7350 (Info.plist)
//
//  SERVER KEY NOTE:
//  - Must match docker-compose.yml:
//    --socket.server_key "jonny_taptap_dev_key_2026"
//

import Foundation
import Nakama

@MainActor
final class NakamaMatchmakingService: ObservableObject {

    // MARK: - Public UI State
    @Published var status: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var isSearching: Bool = false

    @Published var userId: String? = nil
    @Published var username: String? = nil

    @Published var matchmakerTicket: String? = nil
    @Published var matchId: String? = nil

    // MARK: - Config
    struct Config {
        // Your Mac running Docker + Nakama (physical devices must use this IP, not localhost)
        var host: String = "192.168.2.75"

        // Nakama gRPC API port (from docker-compose ports mapping)
        var grpcPort: Int = 7349

        // Nakama realtime socket port (from docker-compose ports mapping)
        var socketPort: Int = 7350

        // Must match your Nakama server config:
        // --socket.server_key "jonny_taptap_dev_key_2026"
        var serverKey: String = "jonny_taptap_dev_key_2026"

        // Local LAN dev = no TLS (http/ws). Set true only if you put Nakama behind HTTPS/WSS.
        var useSSL: Bool = false

        // Create account automatically on first run
        var createAccountIfNeeded: Bool = true

        // Appear online (presence)
        var appearOnline: Bool = true
    }

    private let config: Config

    // MARK: - Nakama Objects
    private var client: Nakama.Client?
    private var session: Nakama.Session?
    private var socket: Nakama.Socket?

    // MARK: - Init
    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Connection Lifecycle

    /// Connect + authenticate + open realtime socket.
    /// Call when the user taps "Online" or enters multiplayer.
    func connect() async {
        if isConnected {
            status = "Already connected"
            return
        }

        do {
            status = "Creating client…"

            let c = Nakama.GrpcClient(
                serverKey: config.serverKey,
                host: config.host,
                port: config.grpcPort,
                ssl: config.useSSL
            )
            self.client = c

            // Device auth (dev-friendly). Keeps the same account by persisting deviceId.
            let deviceId = Self.loadOrCreateDeviceId()
            status = "Authenticating…"

            let s = try await c.authenticateDevice(
                id: deviceId,
                create: config.createAccountIfNeeded,
                username: nil
            )

            self.session = s
            self.userId = s.userId
            self.username = s.username
            status = "Authed ✅ userId: \(s.userId)"

            status = "Creating socket…"
            guard let sock = c.createSocket(host: config.host, port: config.socketPort, ssl: config.useSSL, socketAdapter: nil) as? Nakama.Socket else {
                status = "Failed to create socket"
                return
            }
            self.socket = sock

            wireSocketCallbacks(sock)

            status = "Connecting socket…"
            sock.connect(session: s, appearOnline: config.appearOnline)

            isConnected = true
            status = "Online ✅"

        } catch {
            isConnected = false
            isSearching = false
            matchmakerTicket = nil
            matchId = nil
            status = "Connect failed: \(error.localizedDescription)"
        }
    }

    /// Disconnect socket and reset state.
    func disconnect() async {
        isSearching = false
        matchmakerTicket = nil
        matchId = nil

        if let sock = socket {
            sock.disconnect()
        }

        socket = nil
        session = nil
        client = nil

        isConnected = false
        status = "Offline"
    }

    // MARK: - Matchmaking

    /// Start matchmaking.
    /// - songId/difficulty are used to match players exactly (same song + difficulty).
    /// - minCount/maxCount default to 2 players.
    func startMatchmaking(songId: String, difficulty: String, minCount: Int = 2, maxCount: Int = 2) async {
        guard let sock = socket, isConnected else {
            status = "Not connected"
            return
        }
        if isSearching {
            status = "Already searching"
            return
        }

        do {
            isSearching = true
            matchId = nil
            status = "Entering matchmaking…"

            // IMPORTANT: Keep songId/difficulty simple (letters/numbers/underscores) to avoid query issues.
            // If matching seems flaky, temporarily set query="*" to match anyone.
            let query = "+properties.songId:\(songId) +properties.difficulty:\(difficulty)"

            let ticket = try await sock.addMatchmaker(
                query: query,
                minCount: minCount,
                maxCount: maxCount,
                stringProperties: [
                    "songId": songId,
                    "difficulty": difficulty
                ],
                numericProperties: [:],
                countMultiple: nil
            )

            matchmakerTicket = ticket.ticket
            status = "Searching…"

        } catch {
            isSearching = false
            status = "Matchmaking failed: \(error.localizedDescription)"
        }
    }

    /// Cancel current matchmaking search (if any).
    func cancelMatchmaking() async {
        guard let sock = socket, isConnected else {
            status = "Not connected"
            return
        }
        guard let ticket = matchmakerTicket else {
            status = "No matchmaking ticket"
            return
        }

        do {
            try await sock.removeMatchmaker(ticket: ticket)
            matchmakerTicket = nil
            isSearching = false
            status = "Matchmaking cancelled"
        } catch {
            status = "Cancel failed: \(error.localizedDescription)"
        }
    }

    /// Join the match after `matchId` is set (optional step after match found).
    func joinMatchIfFound() async {
        guard let sock = socket, isConnected else {
            status = "Not connected"
            return
        }
        guard let id = matchId else {
            status = "No matchId yet"
            return
        }

        do {
            status = "Joining match…"
            _ = try await sock.joinMatch(matchId: id, metadata: nil)
            status = "Joined match ✅"
        } catch {
            status = "Join failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Socket Callbacks

    private func wireSocketCallbacks(_ sock: Nakama.Socket) {
        sock.onConnect = { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
                self?.status = "Socket connected ✅"
            }
        }

        sock.onDisconnect = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
                self?.isSearching = false
                self?.matchmakerTicket = nil
                self?.matchId = nil
                self?.status = "Socket disconnected"
            }
        }

        sock.onError = { [weak self] error in
            Task { @MainActor in
                self?.status = "Socket error: \(error.localizedDescription)"
            }
        }

        sock.onMatchmakerMatched = { [weak self] matched in
            Task { @MainActor in
                self?.isSearching = false
                let id = matched.matchID.isEmpty ? nil : matched.matchID
                let token = matched.token.isEmpty ? nil : matched.token
                self?.matchId = id ?? token
                self?.status = "Match found ✅"
            }
        }
    }

    // MARK: - Device ID Persistence

    private static func loadOrCreateDeviceId() -> String {
        let key = "nakama.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
