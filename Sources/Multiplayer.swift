import SwiftUI
import Combine
import AuthenticationServices
import GameKit

struct MultiplayerConfig {
    let restBaseURL: URL
    let wsBaseURL: URL
    let appleClientId: String
    let bundleId: String

    static let `default` = MultiplayerConfig.makeDefault()

    private static func makeDefault() -> MultiplayerConfig {
        let restString = (Bundle.main.object(forInfoDictionaryKey: "MultiplayerBaseURL") as? String) ?? "http://localhost:8080"
        let wsString = (Bundle.main.object(forInfoDictionaryKey: "MultiplayerWSURL") as? String) ?? restString.replacingOccurrences(of: "http", with: "ws") + "/ws"
        return MultiplayerConfig(
            restBaseURL: URL(string: restString)!,
            wsBaseURL: URL(string: wsString)!,
            appleClientId: "com.jonnystaptap.rhythmtap",
            bundleId: "com.jonnystaptap.rhythmtap"
        )
    }
}

struct MultiplayerSession: Codable {
    let userId: String
    let displayName: String
    let provider: String
}

struct LobbySummary: Codable, Identifiable {
    let id: String
    let name: String
    let isPrivate: Bool
    let maxPlayers: Int
    let currentPlayers: Int
    let hostName: String
    let trackId: String
    let difficulty: String
    let status: String
}

struct LobbyMember: Codable, Identifiable {
    let userId: String
    let displayName: String
    let isHost: Bool
    let isReady: Bool
    let joinedAt: Double
    var id: String { userId }
}

struct LobbyChatMessage: Codable, Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let message: String
    let createdAt: Double
}

struct LobbyTrack: Codable {
    let trackId: String
    let difficulty: String
}

struct LobbyState: Codable {
    let id: String
    let name: String
    let isPrivate: Bool
    let maxPlayers: Int
    let hostId: String
    let createdAt: Double
    let updatedAt: Double
    let track: LobbyTrack
    let members: [LobbyMember]
    let chat: [LobbyChatMessage]
    let status: String
    let startAt: Double?
}

struct MultiplayerStartPayload: Equatable {
    let lobbyId: String
    let songId: String
    let difficulty: Difficulty
    let startAt: Date
}

final class MultiplayerStore: NSObject, ObservableObject {
    static let shared = MultiplayerStore()

    @Published var isAuthenticated: Bool = false
    @Published var session: MultiplayerSession?
    @Published var token: String?
    @Published var lobbies: [LobbySummary] = []
    @Published var activeLobby: LobbyState?
    @Published var connectionState: String = "Disconnected"
    @Published var errorMessage: String?
    @Published var pendingStart: MultiplayerStartPayload?
    @Published var serverTimeOffsetMs: Double = 0

    private let config = MultiplayerConfig.default
    private var socket: MultiplayerSocket?
    private var cancellables: Set<AnyCancellable> = []

    func refreshLobbies() {
        MultiplayerAPI.getLobbies(baseURL: config.restBaseURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.lobbies = response
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func checkServer() {
        MultiplayerAPI.health(baseURL: config.restBaseURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    return
                case .failure(let error):
                    self?.errorMessage = "Server unreachable: \(error.localizedDescription)"
                }
            }
        }
    }

    func signInWithApple(identityToken: String) {
        MultiplayerAPI.authApple(baseURL: config.restBaseURL, identityToken: identityToken) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let auth):
                    self?.applyAuth(token: auth.token, session: auth.session)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signInWithGameCenter() {
        Task { @MainActor in
            GameCenterManager.shared.authenticateIfNeeded { [weak self] authenticated in
                guard authenticated else {
                    DispatchQueue.main.async { self?.errorMessage = "Game Center sign-in failed." }
                    return
                }
                MultiplayerAuth.generateGameCenterSignature { signatureResult in
                    DispatchQueue.main.async {
                        switch signatureResult {
                        case .success(let payload):
                            MultiplayerAPI.authGameCenter(baseURL: self?.config.restBaseURL ?? MultiplayerConfig.default.restBaseURL, payload: payload) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success(let auth):
                                        self?.applyAuth(token: auth.token, session: auth.session)
                                    case .failure(let error):
                                        self?.errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        case .failure(let error):
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    func createLobby(name: String, isPrivate: Bool, maxPlayers: Int, trackId: String, difficulty: Difficulty, password: String?) {
        guard let token else { return }
        MultiplayerAPI.createLobby(baseURL: config.restBaseURL, token: token, payload: .init(name: name, isPrivate: isPrivate, maxPlayers: maxPlayers, trackId: trackId, difficulty: difficulty.rawValue, password: password)) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let lobby):
                    self?.activeLobby = lobby
                    self?.connectSocketIfNeeded()
                    self?.subscribeLobby(lobbyId: lobby.id)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func joinLobby(id: String, password: String?) {
        guard let token else { return }
        MultiplayerAPI.joinLobby(baseURL: config.restBaseURL, token: token, lobbyId: id, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let lobby):
                    self?.activeLobby = lobby
                    self?.connectSocketIfNeeded()
                    self?.subscribeLobby(lobbyId: lobby.id)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func leaveLobby() {
        guard let token, let lobbyId = activeLobby?.id else { return }
        MultiplayerAPI.leaveLobby(baseURL: config.restBaseURL, token: token, lobbyId: lobbyId) { [weak self] _ in
            DispatchQueue.main.async {
                self?.activeLobby = nil
            }
        }
    }

    func setReady(_ ready: Bool) {
        guard let lobbyId = activeLobby?.id else { return }
        socket?.send(type: "lobby:ready", payload: ["lobbyId": lobbyId, "ready": ready])
    }

    func sendChat(_ message: String) {
        guard let lobbyId = activeLobby?.id else { return }
        socket?.send(type: "lobby:chat", payload: ["lobbyId": lobbyId, "text": message])
    }

    func requestStart() {
        guard let lobbyId = activeLobby?.id else { return }
        socket?.send(type: "lobby:start", payload: ["lobbyId": lobbyId])
    }

    func updateTrack(trackId: String, difficulty: Difficulty) {
        guard let token, let lobbyId = activeLobby?.id else { return }
        MultiplayerAPI.updateTrack(baseURL: config.restBaseURL, token: token, lobbyId: lobbyId, trackId: trackId, difficulty: difficulty.rawValue) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let lobby) = result {
                    self?.activeLobby = lobby
                }
            }
        }
    }

    func submitScore(trackId: String, difficulty: Difficulty, score: Int, accuracy: Double, maxCombo: Int) {
        guard let token else { return }
        MultiplayerAPI.submitScore(baseURL: config.restBaseURL, token: token, trackId: trackId, difficulty: difficulty.rawValue, score: score, accuracy: accuracy, maxCombo: maxCombo) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyAuth(token: String, session: MultiplayerSession) {
        self.token = token
        self.session = session
        self.isAuthenticated = true
        connectSocketIfNeeded()
        refreshLobbies()
    }

    private func connectSocketIfNeeded() {
        guard socket == nil, let token else { return }
        let wsURL = config.wsBaseURL.appending(queryItems: [URLQueryItem(name: "token", value: token)])
        let socket = MultiplayerSocket(url: wsURL)
        socket.onLobbyUpdate = { [weak self] lobby in
            DispatchQueue.main.async {
                self?.activeLobby = lobby
                self?.handleStartIfNeeded(lobby: lobby)
            }
        }
        socket.onTimeSync = { [weak self] offset in
            DispatchQueue.main.async {
                self?.serverTimeOffsetMs = offset
            }
        }
        socket.onStateChange = { [weak self] state in
            DispatchQueue.main.async { self?.connectionState = state }
        }
        socket.onError = { [weak self] message in
            DispatchQueue.main.async { self?.errorMessage = message }
        }
        socket.connect()
        self.socket = socket
    }

    private func subscribeLobby(lobbyId: String) {
        socket?.send(type: "lobby:subscribe", payload: ["lobbyId": lobbyId])
    }

    private func handleStartIfNeeded(lobby: LobbyState) {
        guard let startAtMs = lobby.startAt else { return }
        let difficulty = Difficulty(rawValue: lobby.track.difficulty) ?? .medium
        let startDate = Date(timeIntervalSince1970: startAtMs / 1000.0)
        pendingStart = MultiplayerStartPayload(
            lobbyId: lobby.id,
            songId: lobby.track.trackId,
            difficulty: difficulty,
            startAt: startDate
        )
    }

    /// Call after consuming `pendingStart` to avoid re-triggering navigation.
    func clearPendingStart() {
        pendingStart = nil
    }
}

struct MultiplayerAuthPayload: Codable {
    let playerID: String
    let bundleID: String
    let publicKeyUrl: String
    let signature: String
    let salt: String
    let timestamp: String
    let displayName: String?
}

enum MultiplayerAuthError: Error {
    case missingSignature
}

final class MultiplayerAuth: NSObject {
    static func generateGameCenterSignature(completion: @escaping (Result<MultiplayerAuthPayload, Error>) -> Void) {
        GKLocalPlayer.local.fetchItems(forIdentityVerificationSignature: { publicKeyUrl, signature, salt, timestamp, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let publicKeyUrl, let signature, let salt else {
                completion(.failure(MultiplayerAuthError.missingSignature))
                return
            }
            let payload = MultiplayerAuthPayload(
                playerID: GKLocalPlayer.local.gamePlayerID,
                bundleID: Bundle.main.bundleIdentifier ?? "",
                publicKeyUrl: publicKeyUrl.absoluteString,
                signature: signature.base64EncodedString(),
                salt: salt.base64EncodedString(),
                timestamp: String(timestamp),
                displayName: GKLocalPlayer.local.displayName
            )
            completion(.success(payload))
        })
    }
}

final class MultiplayerSocket: NSObject, URLSessionWebSocketDelegate {
    private let url: URL
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveTimer: Timer?
    private var syncTimer: Timer?
    private var reconnectTimer: Timer?

    var onLobbyUpdate: ((LobbyState) -> Void)?
    var onTimeSync: ((Double) -> Void)?
    var onStateChange: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var serverOffsetSamples: [Double] = []

    init(url: URL) {
        self.url = url
    }

    func connect() {
        onStateChange?("Connecting")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        task = session.webSocketTask(with: url)
        task?.resume()
        listen()
        scheduleTimeSync()
    }

    func send(type: String, payload: [String: Any]) {
        let message: [String: Any] = ["type": type, "payload": payload]
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        task?.send(.data(data)) { _ in }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleMessage(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self.handleMessage(data)
                    }
                @unknown default:
                    break
                }
                self.listen()
            case .failure(let error):
                self.onStateChange?("Disconnected")
                self.onError?("WebSocket receive failed: \(error.localizedDescription)")
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "lobby:update", let payload = json["payload"] {
            if let lobbyData = try? JSONSerialization.data(withJSONObject: payload),
               let lobby = try? JSONDecoder().decode(LobbyState.self, from: lobbyData) {
                onLobbyUpdate?(lobby)
            }
        } else if type == "timeSync", let payload = json["payload"] as? [String: Any], let serverTime = payload["serverTime"] as? Double {
            let now = Date().timeIntervalSince1970 * 1000
            onTimeSync?(serverTime - now)
        } else if type == "timeSyncPong", let payload = json["payload"] as? [String: Any],
                  let clientTime = payload["clientTime"] as? Double,
                  let serverTime = payload["serverTime"] as? Double {
            let now = Date().timeIntervalSince1970 * 1000
            let rtt = now - clientTime
            let offset = serverTime - (clientTime + rtt / 2.0)
            serverOffsetSamples.append(offset)
            if serverOffsetSamples.count > 5 {
                serverOffsetSamples.removeFirst()
            }
            let avg = serverOffsetSamples.reduce(0, +) / Double(serverOffsetSamples.count)
            onTimeSync?(avg)
        } else if type == "error", let payload = json["payload"] as? [String: Any] {
            onError?(payload["message"] as? String ?? "Error")
        }
    }

    private func scheduleTimeSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pingTimeSync()
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    private func pingTimeSync() {
        let clientTime = Date().timeIntervalSince1970 * 1000
        send(type: "timeSyncPing", payload: ["clientTime": clientTime])
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onStateChange?("Connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onStateChange?("Disconnected")
        if let reason, let reasonString = String(data: reason, encoding: .utf8), !reasonString.isEmpty {
            onError?("WebSocket closed (\(closeCode.rawValue)): \(reasonString)")
        } else {
            onError?("WebSocket closed (\(closeCode.rawValue))")
        }
    }
}

struct MultiplayerAPI {
    struct APIErrorResponse: Codable {
        let error: String
    }

    struct AuthResponse: Codable {
        let token: String
        let session: MultiplayerSession
    }

    struct LobbyResponse: Codable {
        let lobby: LobbyState
    }

    struct LobbyListResponse: Codable {
        let lobbies: [LobbySummary]
    }

    struct HealthResponse: Codable {
        let ok: Bool
    }

    struct CreateLobbyPayload: Codable {
        let name: String
        let isPrivate: Bool
        let maxPlayers: Int
        let trackId: String
        let difficulty: String
        let password: String?
    }

    struct AppleAuthPayload: Codable {
        let identityToken: String
    }

    struct JoinLobbyPayload: Codable {
        let password: String
    }

    struct TrackPayload: Codable {
        let trackId: String
        let difficulty: String
    }

    struct SubmitScorePayload: Codable {
        let trackId: String
        let difficulty: String
        let score: Int
        let accuracy: Double
        let maxCombo: Int
    }

    struct EmptyPayload: Codable {}

    static func authApple(baseURL: URL, identityToken: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("auth/apple")
        post(url: url, token: nil, body: AppleAuthPayload(identityToken: identityToken), completion: completion)
    }

    static func authGameCenter(baseURL: URL, payload: MultiplayerAuthPayload, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("auth/gamecenter")
        post(url: url, token: nil, body: payload, completion: completion)
    }

    static func getLobbies(baseURL: URL, completion: @escaping (Result<[LobbySummary], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("lobbies")
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error { return completion(.failure(error)) }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return completion(.failure(makeAPIError(status: http.statusCode, data: data)))
            }
            guard let data,
                  let response = try? JSONDecoder().decode(LobbyListResponse.self, from: data) else {
                return completion(.failure(NSError(domain: "Lobby", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid lobby response"
                ])))
            }
            completion(.success(response.lobbies))
        }
        task.resume()
    }

    static func health(baseURL: URL, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("health")
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error { return completion(.failure(error)) }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return completion(.failure(makeAPIError(status: http.statusCode, data: data)))
            }
            guard let data,
                  let response = try? JSONDecoder().decode(HealthResponse.self, from: data) else {
                return completion(.failure(NSError(domain: "API", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid health response"
                ])))
            }
            completion(.success(response.ok))
        }
        task.resume()
    }

    static func createLobby(baseURL: URL, token: String, payload: CreateLobbyPayload, completion: @escaping (Result<LobbyState, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("lobbies")
        post(url: url, token: token, body: payload) { (result: Result<LobbyResponse, Error>) in
            completion(result.map { $0.lobby })
        }
    }

    static func joinLobby(baseURL: URL, token: String, lobbyId: String, password: String?, completion: @escaping (Result<LobbyState, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("lobbies").appendingPathComponent(lobbyId).appendingPathComponent("join")
        post(url: url, token: token, body: JoinLobbyPayload(password: password ?? "")) { (result: Result<LobbyResponse, Error>) in
            completion(result.map { $0.lobby })
        }
    }

    static func leaveLobby(baseURL: URL, token: String, lobbyId: String, completion: @escaping (Result<LobbyState?, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("lobbies").appendingPathComponent(lobbyId).appendingPathComponent("leave")
        post(url: url, token: token, body: EmptyPayload()) { (result: Result<LobbyResponse, Error>) in
            completion(result.map { $0.lobby })
        }
    }

    static func updateTrack(baseURL: URL, token: String, lobbyId: String, trackId: String, difficulty: String, completion: @escaping (Result<LobbyState, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("lobbies").appendingPathComponent(lobbyId).appendingPathComponent("track")
        post(url: url, token: token, body: TrackPayload(trackId: trackId, difficulty: difficulty)) { (result: Result<LobbyResponse, Error>) in
            completion(result.map { $0.lobby })
        }
    }

    static func submitScore(baseURL: URL, token: String, trackId: String, difficulty: String, score: Int, accuracy: Double, maxCombo: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("leaderboards").appendingPathComponent("submit")
        post(url: url, token: token, body: SubmitScorePayload(trackId: trackId, difficulty: difficulty, score: score, accuracy: accuracy, maxCombo: maxCombo)) { (result: Result<[String: Bool], Error>) in
            completion(result.map { $0["ok"] ?? false })
        }
    }

    private static func post<T: Encodable, R: Decodable>(url: URL, token: String?, body: T, completion: @escaping (Result<R, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(body)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { return completion(.failure(error)) }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return completion(.failure(makeAPIError(status: http.statusCode, data: data)))
            }
            guard let data,
                  let response = try? JSONDecoder().decode(R.self, from: data) else {
                return completion(.failure(NSError(domain: "API", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid API response"
                ])))
            }
            completion(.success(response))
        }
        task.resume()
    }

    private static func makeAPIError(status: Int, data: Data?) -> Error {
        if let data,
           let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           !payload.error.isEmpty {
            return NSError(domain: "API", code: status, userInfo: [
                NSLocalizedDescriptionKey: payload.error
            ])
        }
        return NSError(domain: "API", code: status, userInfo: [
            NSLocalizedDescriptionKey: "API error \(status)"
        ])
    }
}

struct MultiplayerLobbyView: View {
    @ObservedObject private var store = MultiplayerStore.shared
    @State private var showCreate = false
    @State private var lobbyName = ""
    @State private var lobbyPassword = ""
    @State private var isPrivate = false
    @State private var maxPlayers = 4
    @State private var chatText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                if let error = store.errorMessage {
                    Button(action: { store.errorMessage = nil }) {
                        Text(error)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.9, green: 0.2, blue: 0.2))
                            .cornerRadius(8)
                    }
                }
                if !store.isAuthenticated {
                    authSection
                } else {
                    lobbyList
                    activeLobbyView
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
        }
        .onAppear {
            store.checkServer()
            store.refreshLobbies()
        }
    }

    private var header: some View {
        HStack {
            Text("MULTIPLAYER LOBBY")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Text(store.connectionState)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
    }

    private var authSection: some View {
        VStack(spacing: 12) {
            Text("Sign in to join or create lobbies")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken,
                          let token = String(data: tokenData, encoding: .utf8) else { return }
                    store.signInWithApple(identityToken: token)
                case .failure(let error):
                    store.errorMessage = error.localizedDescription
                }
            }
            .frame(height: 44)

            Button(action: { store.signInWithGameCenter() }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("USE GAME CENTER")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.45, green: 0.0, blue: 0.05))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .foregroundColor(.white)
        }
        .padding(.vertical, 12)
    }

    private var lobbyList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PUBLIC LOBBIES")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Button("REFRESH") { store.refreshLobbies() }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.lobbies) { lobby in
                        Button(action: { store.joinLobby(id: lobby.id, password: nil) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lobby.name.uppercased())
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                    Text("\(lobby.trackId.uppercased()) · \(lobby.difficulty.uppercased())")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                Text("\(lobby.currentPlayers)/\(lobby.maxPlayers)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(10)
                            .background(LinearGradient(colors: [Color(red: 0.18, green: 0.02, blue: 0.05), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 180)

            Button(action: { showCreate = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("CREATE LOBBY")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.4, green: 0.0, blue: 0.05))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showCreate) {
            createLobbySheet
        }
    }

    private var activeLobbyView: some View {
        Group {
            if let lobby = store.activeLobby {
                VStack(spacing: 10) {
                    HStack {
                        Text("LOBBY: \(lobby.name.uppercased())")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        Spacer()
                        Button("LEAVE") { store.leaveLobby() }
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRACK: \(lobby.track.trackId.uppercased())")
                        Text("DIFFICULTY: \(lobby.track.difficulty.uppercased())")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 6) {
                        Button("READY") { store.setReady(true) }
                        Button("UNREADY") { store.setReady(false) }
                        Button("START") { store.requestStart() }
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.25, green: 0.0, blue: 0.05))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(lobby.chat) { message in
                                Text("\(message.displayName): \(message.message)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(height: 120)

                    HStack {
                        TextField("Type message...", text: $chatText)
                            .textFieldStyle(.roundedBorder)
                        Button("SEND") {
                            let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            store.sendChat(trimmed)
                            chatText = ""
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.55, green: 0.0, blue: 0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private var createLobbySheet: some View {
        VStack(spacing: 12) {
            Text("CREATE LOBBY")
                .font(.system(size: 18, weight: .black, design: .rounded))
            TextField("Lobby name", text: $lobbyName)
                .textFieldStyle(.roundedBorder)
            Toggle("Private", isOn: $isPrivate)
            if isPrivate {
                TextField("Password", text: $lobbyPassword)
                    .textFieldStyle(.roundedBorder)
            }
            Stepper("Max Players: \(maxPlayers)", value: $maxPlayers, in: 2...8)

            Button("CREATE") {
                let defaultSong = SongMetadata.library.first?.id ?? "default"
                store.createLobby(name: lobbyName.isEmpty ? "Metal Room" : lobbyName,
                                  isPrivate: isPrivate,
                                  maxPlayers: maxPlayers,
                                  trackId: defaultSong,
                                  difficulty: .medium,
                                  password: isPrivate ? lobbyPassword : nil)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.45, green: 0.0, blue: 0.05))
            .cornerRadius(10)
            .foregroundColor(.white)

            Spacer()
        }
        .padding(20)
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = queryItems
        return components.url ?? self
    }
}
