import Foundation
import Combine

enum Judgement {
    case perfect
    case great
    case good
    case miss

    var scoreValue: Int {
        switch self {
        case .perfect: return 1000
        case .great: return 600
        case .good: return 300
        case .miss: return 0
        }
    }
    
    var accuracyModifier: Double {
        switch self {
        case .perfect: return 1.0
        case .great: return 0.8
        case .good: return 0.6
        case .miss: return 0.0
        }
    }
}

@MainActor
final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var lastJudgement: Judgement = .perfect
    @Published var missedNotes: Int = 0
    @Published var isFailed: Bool = false
    @Published var totalNotes: Int = 0
    @Published var notesHit: Int = 0
    @Published var badTaps: Int = 0
    @Published var isCompleted: Bool = false
    @Published var personalBest: Int = 0
    @Published var isNewPersonalBest: Bool = false
    @Published var multiplier: Int = 1
    @Published var experience: Int = 0
    @Published var totalXP: Int64 = 0
    @Published var level: Int = 1
    @Published var revengeActive: Bool = false
    @Published var revengeEndTime: Double = 0
    @Published var difficulty: Difficulty = .medium
    @Published var songID: String = "track3"
    @Published var songTitle: String = "Hallelujah"
    @Published var songChartFiles: ChartFiles = ChartFiles(same: "chart")
    @Published var customBeatmap: Beatmap? = nil
    @Published var tapCoins: Int = 0 // Player now always starts with 0 coins
    @Published var unlockedSongIDs: Set<String> = ["hallelujah"]
    @Published var lastCoinsEarned: Int = 0
    
    private let missLimit = 100
    private let revengeThreshold = 30
    private let revengeDuration: Double = 8.0
    private var revengeMultiplier: Int = 2
    private let personalBestKeyPrefix = "personalBest_"
    private var accountCancellable: AnyCancellable?

    init() {
        accountCancellable = AccountManager.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.tapCoins = state.coinsBalance
                self.unlockedSongIDs = state.ownedSongIds
                self.totalXP = state.xpTotal
                self.level = state.level
            }
    }

    func registerHit(_ judgement: Judgement) {
        if isFailed { return }
        let settings = SettingsManager.shared
        
        var points = judgement.scoreValue
        
        // Apply multiplier
        points = Int(Double(points) * Double(multiplier))
        
        if revengeActive && settings.revengeModeEnabled {
            points = points * revengeMultiplier
        }
        
        score += points
        
        if judgement == .miss {
            combo = 0
            multiplier = 1
            missedNotes += 1
            revengeActive = false
            
            if settings.failModeEnabled && missedNotes >= missLimit {
                isFailed = true
            }
        } else {
            combo += 1
            maxCombo = max(maxCombo, combo)
            notesHit += 1
            
            // Increase multiplier every 10 hits
            multiplier = 1 + (combo / 10)
            
            // Award experience
            experience += Int(Double(judgement.scoreValue) * 0.1)
        }
        
        lastJudgement = judgement
    }
    
    func activateRevengeMode(currentTime: Double) {
        if SettingsManager.shared.revengeModeEnabled && !revengeActive && combo >= revengeThreshold {
            revengeActive = true
            revengeEndTime = currentTime + revengeDuration
        }
    }
    
    func updateRevengeMode(currentTime: Double) {
        if !SettingsManager.shared.revengeModeEnabled {
            revengeActive = false
            return
        }
        if revengeActive && currentTime >= revengeEndTime {
            revengeActive = false
        }
    }
    
    func canActivateRevenge() -> Bool {
        SettingsManager.shared.revengeModeEnabled && combo >= revengeThreshold && !revengeActive
    }

    func setDifficulty(_ difficulty: Difficulty) {
        self.difficulty = difficulty
        loadPersonalBest()
        isNewPersonalBest = false
    }

    func setSong(_ song: SongMetadata) {
        songID = song.id
        songTitle = song.title
        songChartFiles = song.chartFiles
        if song.id != "user_beatmap" {
            customBeatmap = nil
        }
        loadPersonalBest()
        isNewPersonalBest = false
    }
    
    func registerBadTap() {
        badTaps += 1
        combo = 0
        multiplier = 1
    }
    
    func markCompleted() {
        isCompleted = true
        updatePersonalBestIfNeeded()
        awardTapCoins()
        saveProgress()
    }

    private func personalBestKey() -> String {
        return personalBestKeyPrefix + songID + "_" + difficulty.rawValue
    }
    
    private func loadPersonalBest() {
        personalBest = UserDefaults.standard.integer(forKey: personalBestKey())
    }
    
    private func updatePersonalBestIfNeeded() {
        let currentBest = UserDefaults.standard.integer(forKey: personalBestKey())
        if score > currentBest {
            personalBest = score
            isNewPersonalBest = true
            UserDefaults.standard.set(score, forKey: personalBestKey())
        } else {
            personalBest = currentBest
            isNewPersonalBest = false
        }
    }

    private func awardTapCoins() {
        let coins = EconomyConfig.coinsForCompletion(
            score: score,
            totalNotes: totalNotes,
            notesHit: notesHit,
            maxCombo: maxCombo,
            difficulty: difficulty
        )
        lastCoinsEarned = coins
        AccountManager.shared.addCoins(coins)
    }

    func saveProgress() {
        AccountManager.shared.persistCurrentState()
    }

    func saveProgressLocal() {
        // Deprecated: account-scoped persistence now handled by AccountManager.
    }

    func loadProgress() {
        AccountManager.shared.loadOnLaunch()
    }

    func loadProgressCloud() {
        // Deprecated: CloudKit persistence is handled by AccountManager.
    }

    func reset() {
        score = 0
        combo = 0
        maxCombo = 0
        missedNotes = 0
        notesHit = 0
        badTaps = 0
        isFailed = false
        isCompleted = false
        isNewPersonalBest = false
        totalNotes = 0
        multiplier = 1
        experience = 0
        revengeActive = false
        revengeEndTime = 0
        lastJudgement = .perfect
        lastCoinsEarned = 0
        loadPersonalBest()
    }

    func resetLocalProgress() {
        lastCoinsEarned = 0
        experience = 0
        personalBest = 0
        isNewPersonalBest = false
        AccountManager.shared.resetCurrentAccount()

        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(personalBestKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    func clearPersonalBest(songID: String, difficulty: Difficulty) {
        let key = personalBestKeyPrefix + songID + "_" + difficulty.rawValue
        UserDefaults.standard.removeObject(forKey: key)
        if self.songID == songID && self.difficulty == difficulty {
            personalBest = 0
            isNewPersonalBest = false
        }
    }

    @discardableResult
    func awardXP(result: SongResult) -> LevelUpResult {
        AccountManager.shared.applyXP(result: result)
    }

    @discardableResult
    func purchaseSong(songId: String, price: Int) -> Bool {
        AccountManager.shared.purchaseSong(songId: songId, price: price)
    }
}
