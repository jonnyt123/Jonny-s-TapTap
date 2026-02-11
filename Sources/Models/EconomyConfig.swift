import Foundation

/// Central configuration for in-game economy: song prices and Tap Coin rewards.
/// All rewards are earned by playing; no real-money or pay-to-win mechanics.
enum EconomyConfig {
    // MARK: - Song prices (Tap Coins)

    /// Default price when a song has no explicit entry (fallback for new songs).
    static let defaultSongPrice = 100

    /// Price per song by ID. Songs not listed use `defaultSongPrice` or index-based fallback.
    private static let songPricesById: [String: Int] = [
        "21_guns": 50,
        "green_day_holiday": 120,
        "dragonforce_ttfaf": 100,
        "hallelujah": 0, // free / default track, not sold
        "test_song": 90,
        "crazy_train": 80,
        "i_will_not_bow": 95,
        "day_n_nite": 105,
        "blink182_see_you": 85,
        "madchild_chainsaw": 130,
        "hippie_sabotage_high": 140,
        "mgk_dont_let_me_go": 150,
        "coldplay_viva_la_vida": 160,
        "bizzy_banks_fonem": 170,
    ]

    /// Price for a purchasable song. Uses explicit price if set, else default.
    static func price(forSongId songId: String) -> Int {
        if let price = songPricesById[songId] { return price }
        return defaultSongPrice
    }

    /// Whether this song is purchasable in the shop (not the free default track).
    static func isPurchasable(songId: String) -> Bool {
        price(forSongId: songId) > 0
    }

    // MARK: - Tap Coin rewards (earned by playing)

    static let coinRewardBase: Double = 10.0
    static let coinRewardMin = 5
    static let coinRewardMax = 250
    /// Score divisor so typical scores contribute ~0–1 to reward (e.g. score/1200).
    static let coinRewardScoreDivisor: Double = 1200.0
    /// Combo divisor for combo bonus (e.g. maxCombo/25).
    static let coinRewardComboDivisor: Double = 25.0
    /// Minimum accuracy factor (0–1) so low accuracy still gives some reward.
    static let coinRewardMinAccuracyFactor: Double = 0.5

    /// Difficulty multipliers for coin reward (no pay-to-win: harder = more reward).
    static func coinRewardDifficultyMultiplier(_ difficulty: Difficulty) -> Double {
        switch difficulty {
        case .easy: return 1.0
        case .medium: return 1.25
        case .hard: return 1.5
        case .extreme: return 2.0
        }
    }

    /// Compute Tap Coins earned for a completed song (performance-based only).
    static func coinsForCompletion(
        score: Int,
        totalNotes: Int,
        notesHit: Int,
        maxCombo: Int,
        difficulty: Difficulty
    ) -> Int {
        let accuracy = totalNotes > 0 ? Double(notesHit) / Double(totalNotes) : 0.0
        let accuracyFactor = max(coinRewardMinAccuracyFactor, accuracy)
        let scoreComponent = Double(score) / coinRewardScoreDivisor
        let comboComponent = Double(maxCombo) / coinRewardComboDivisor
        let mult = coinRewardDifficultyMultiplier(difficulty)
        let raw = (coinRewardBase + scoreComponent + comboComponent) * accuracyFactor * mult
        return max(coinRewardMin, min(Int(raw.rounded()), coinRewardMax))
    }
}
