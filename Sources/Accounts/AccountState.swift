import Foundation

struct AccountState: Codable, Equatable {
    let userId: String
    var username: String?
    var level: Int
    var xpTotal: Int64
    var coinsBalance: Int
    var ownedSongIds: Set<String>
    let createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int

    var isGuest: Bool { userId == AccountState.guestUserId }

    static let schemaVersionCurrent = 1
    static let guestUserId = "guest"

    static func newGuest(starterSongs: Set<String>) -> AccountState {
        AccountState(
            userId: guestUserId,
            username: nil,
            level: 1,
            xpTotal: 0,
            coinsBalance: 0,
            ownedSongIds: starterSongs,
            createdAt: Date(),
            updatedAt: Date(),
            schemaVersion: schemaVersionCurrent
        )
    }

    static func newSignedIn(userId: String, starterSongs: Set<String>) -> AccountState {
        AccountState(
            userId: userId,
            username: nil,
            level: 1,
            xpTotal: 0,
            coinsBalance: 0,
            ownedSongIds: starterSongs,
            createdAt: Date(),
            updatedAt: Date(),
            schemaVersion: schemaVersionCurrent
        )
    }
}
