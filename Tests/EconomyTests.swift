import XCTest
@testable import RhythmTap

// MARK: - EconomyConfig (wallet math: prices and coin rewards)

final class EconomyTests: XCTestCase {

    func testEconomyConfigPriceAndPurchasable() {
        XCTAssertEqual(EconomyConfig.price(forSongId: "hallelujah"), 0)
        XCTAssertFalse(EconomyConfig.isPurchasable(songId: "hallelujah"))

        XCTAssertEqual(EconomyConfig.price(forSongId: "21_guns"), 50)
        XCTAssertTrue(EconomyConfig.isPurchasable(songId: "21_guns"))

        XCTAssertEqual(EconomyConfig.price(forSongId: "green_day_holiday"), 120)
        XCTAssertEqual(EconomyConfig.price(forSongId: "coldplay_viva_la_vida"), 160)

        XCTAssertEqual(EconomyConfig.price(forSongId: "unknown_song"), EconomyConfig.defaultSongPrice)
        XCTAssertTrue(EconomyConfig.isPurchasable(songId: "unknown_song"))
    }

    func testEconomyConfigCoinsForCompletionClamp() {
        // Minimum reward even with poor performance
        let minCoins = EconomyConfig.coinsForCompletion(
            score: 0,
            totalNotes: 100,
            notesHit: 50,
            maxCombo: 0,
            difficulty: .easy
        )
        XCTAssertGreaterThanOrEqual(minCoins, EconomyConfig.coinRewardMin)
        XCTAssertLessThanOrEqual(minCoins, EconomyConfig.coinRewardMax)

        // High performance on extreme
        let maxCoins = EconomyConfig.coinsForCompletion(
            score: 1_000_000,
            totalNotes: 500,
            notesHit: 500,
            maxCombo: 200,
            difficulty: .extreme
        )
        XCTAssertLessThanOrEqual(maxCoins, EconomyConfig.coinRewardMax)
        XCTAssertGreaterThanOrEqual(maxCoins, EconomyConfig.coinRewardMin)
    }

    func testEconomyConfigDifficultyMultipliers() {
        let base = (score: 50_000, notes: 100, hit: 80, combo: 20)
        let easy = EconomyConfig.coinsForCompletion(
            score: base.score,
            totalNotes: base.notes,
            notesHit: base.hit,
            maxCombo: base.combo,
            difficulty: .easy
        )
        let medium = EconomyConfig.coinsForCompletion(
            score: base.score,
            totalNotes: base.notes,
            notesHit: base.hit,
            maxCombo: base.combo,
            difficulty: .medium
        )
        let hard = EconomyConfig.coinsForCompletion(
            score: base.score,
            totalNotes: base.notes,
            notesHit: base.hit,
            maxCombo: base.combo,
            difficulty: .hard
        )
        let extreme = EconomyConfig.coinsForCompletion(
            score: base.score,
            totalNotes: base.notes,
            notesHit: base.hit,
            maxCombo: base.combo,
            difficulty: .extreme
        )
        XCTAssertLessThanOrEqual(easy, medium)
        XCTAssertLessThanOrEqual(medium, hard)
        XCTAssertLessThanOrEqual(hard, extreme)
    }

    func testEconomyConfigNoNegativeOrZeroFromReasonableInput() {
        for difficulty in [Difficulty.easy, .medium, .hard, .extreme] {
            let coins = EconomyConfig.coinsForCompletion(
                score: 0,
                totalNotes: 10,
                notesHit: 5,
                maxCombo: 0,
                difficulty: difficulty
            )
            XCTAssertGreaterThan(coins, 0, "difficulty: \(difficulty)")
        }
    }

    // MARK: - Unlock persistence (LocalProfileStore round-trip)

    func testUnlockPersistenceRoundTrip() async throws {
        let key = "test.economy.\(UUID().uuidString)"
        let store = LocalProfileStore(storageKey: key)
        defer {
            UserDefaults.standard.removeObject(forKey: key)
        }

        var state = AccountState.newGuest(starterSongs: ["hallelujah"])
        state.coinsBalance = 75
        state.ownedSongIds = ["hallelujah", "21_guns", "green_day_holiday"]

        await store.save(state)

        let loaded = await store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.coinsBalance, 75)
        XCTAssertEqual(loaded?.ownedSongIds, Set(["hallelujah", "21_guns", "green_day_holiday"]))
    }

    func testUnlockPersistenceEmptyOwnedStillHasStarter() async throws {
        let key = "test.economy.\(UUID().uuidString)"
        let store = LocalProfileStore(storageKey: key)
        defer {
            UserDefaults.standard.removeObject(forKey: key)
        }

        let state = AccountState.newGuest(starterSongs: ["hallelujah"])
        await store.save(state)

        let loaded = await store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.coinsBalance, 0)
        XCTAssertTrue(loaded?.ownedSongIds.contains("hallelujah") == true)
    }
}
