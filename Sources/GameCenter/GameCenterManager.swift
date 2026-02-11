import Foundation
import GameKit

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var authState: GameCenterAuthState = .idle
    @Published private(set) var lastError: String?

    private override init() {
        super.init()
    }

    func authenticateIfNeeded(completion: ((Bool) -> Void)? = nil) {
        if GKLocalPlayer.local.isAuthenticated {
            authState = .authenticated(displayName: GKLocalPlayer.local.displayName)
            completion?(true)
            return
        }
        authState = .authenticating
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController {
                GameCenterPresenter.present(viewController)
                return
            }
            if let error {
                self.authState = .notAuthenticated(reason: error.localizedDescription)
                self.lastError = error.localizedDescription
                completion?(false)
                return
            }
            if GKLocalPlayer.local.isAuthenticated {
                let name = GKLocalPlayer.local.displayName
                self.authState = .authenticated(displayName: name)
                // Suppress GameKit monogram caching by preloading photo
                if #available(iOS 18.0, *) {
                    GKLocalPlayer.local.loadPhoto(for: .normal) { _, _ in }
                }
                completion?(true)
            } else if GKLocalPlayer.local.isMultiplayerGamingRestricted || GKLocalPlayer.local.isPersonalizedCommunicationRestricted {
                self.authState = .notAuthenticated(reason: "Restricted by parental controls.")
                completion?(false)
            } else {
                self.authState = .notAuthenticated(reason: "Not signed in.")
                completion?(false)
            }
        }
    }

    func presentLeaderboards(leaderboardID: String? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateIfNeeded()
            return
        }
        let vc: GKGameCenterViewController
        if let leaderboardID {
            vc = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            vc = GKGameCenterViewController(state: .leaderboards)
        }
        vc.gameCenterDelegate = self
        GameCenterPresenter.present(vc)
    }

    func presentDashboard() {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateIfNeeded()
            return
        }
        let vc = GKGameCenterViewController(state: .dashboard)
        vc.gameCenterDelegate = self
        GameCenterPresenter.present(vc)
    }

    func submitResult(_ result: GCSongResult) {
        LeaderboardService.shared.submit(result: result)
    }

    func challengeFriends(result: GCSongResult, message: String? = nil) {
        if let leaderboardID = GameCenterConfiguration.scoreLeaderboardID(for: result.difficulty) {
            ChallengeService.shared.challengeScore(leaderboardID: leaderboardID, value: Int64(result.score), message: message)
        }
    }
}

@MainActor
extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
