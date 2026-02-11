import SwiftUI

@MainActor
struct GameCenterStatusView: View {
    @ObservedObject var manager: GameCenterManager

    init() {
        self.manager = GameCenterManager.shared
    }

    init(manager: GameCenterManager) {
        self.manager = manager
    }

    var body: some View {
        HStack(spacing: 10) {
            statusLabel
            Spacer()
            Button(action: { Task { await MainActor.run { manager.authenticateIfNeeded() } } }) {
                Text(buttonTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .onAppear {
            Task { await MainActor.run { manager.authenticateIfNeeded() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await MainActor.run { manager.authenticateIfNeeded() } }
        }
    }

    private var statusLabel: some View {
        switch manager.authState {
        case .authenticated(let name):
            return Text("Game Center: \(name)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        case .authenticating:
            return Text("Game Center: Connecting...")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        case .notAuthenticated(let reason):
            return Text("Game Center: \(reason)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        case .idle:
            return Text("Game Center: Idle")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var buttonTitle: String {
        switch manager.authState {
        case .authenticated:
            return "Connected"
        case .authenticating:
            return "Connecting..."
        case .notAuthenticated:
            return "Sign In"
        case .idle:
            return "Sign In"
        }
    }
}

@MainActor
struct LeaderboardsButton: View {
    var body: some View {
        Button(action: {
            Task { await MainActor.run { GameCenterManager.shared.presentLeaderboards() } }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                Text("VIEW LEADERBOARDS")
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .buttonStyle(.borderedProminent)
    }
}

struct ChallengeFriendsSheet: View {
    let result: GCSongResult
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Challenge friends to beat your score.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                TextField("Optional message", text: $message)
                    .textFieldStyle(.roundedBorder)
                Button("Send Challenge") {
                    Task { await MainActor.run { GameCenterManager.shared.challengeFriends(result: result, message: message) } }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .navigationTitle("Challenge Friends")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

@MainActor
struct GameCenterDebugView: View {
    @ObservedObject private var manager = GameCenterManager.shared
    @State private var lastSubmitted: String = "None"

    var body: some View {
        VStack(spacing: 12) {
            GameCenterStatusView(manager: manager)
            Text("Last submitted: \(lastSubmitted)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Button("Submit Dummy Score") {
                let dummy = GCSongResult(
                    songId: "test_song",
                    difficulty: "normal",
                    score: 12345,
                    accuracyPercent: 96.2,
                    maxCombo: 321,
                    didFC: false,
                    timestamp: Date()
                )
                Task { await MainActor.run { GameCenterManager.shared.submitResult(dummy) } }
                lastSubmitted = "Score 12345 @ \(Date())"
            }
            .buttonStyle(.bordered)
            LeaderboardsButton()
            Button("Open Game Center") {
                Task { await MainActor.run { GameCenterManager.shared.presentDashboard() } }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
    }
}
