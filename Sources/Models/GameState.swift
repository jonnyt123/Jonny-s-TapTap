import Foundation

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

final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var health: Double = 1.0
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
    private let tapCoinsKey = "tapCoins"
    private let unlockedSongsKey = "unlockedSongs"
    private let xpKey = "playerTotalXP"
    private let levelKey = "playerLevel"

    private let xpThresholds = LevelingCurve.powerCurve(exponent: 2.2)

    func registerHit(_ judgement: Judgement) {
        if isFailed { return }
        
        var points = judgement.scoreValue
        
        // Apply multiplier
        points = Int(Double(points) * Double(multiplier))
        
        let revengeModeEnabled = UserDefaults.standard.bool(forKey: "revengeModeEnabled")
        if revengeActive && revengeModeEnabled {
            points = points * revengeMultiplier
        }
        
        score += points
        
        if judgement == .miss {
            combo = 0
            multiplier = 1
            missedNotes += 1
            revengeActive = false
            
            // Health depletes based on missed notes
            health = max(0, 1.0 - Double(missedNotes) / Double(missLimit))
            
            if missedNotes >= missLimit {
                isFailed = true
                health = 0.0
            }
        } else {
            combo += 1
            maxCombo = max(maxCombo, combo)
            notesHit += 1
            
            // Increase multiplier every 10 hits
            multiplier = 1 + (combo / 10)
            
            // Award experience
            experience += Int(Double(judgement.scoreValue) * 0.1)
            
            // Health recovers slightly on hits
            health = min(1.0, health + 0.01)
        }
        
        lastJudgement = judgement
    }
    
    func activateRevengeMode(currentTime: Double) {
        let revengeModeEnabled = UserDefaults.standard.bool(forKey: "revengeModeEnabled")
        if revengeModeEnabled && !revengeActive && combo >= revengeThreshold {
            revengeActive = true
            revengeEndTime = currentTime + revengeDuration
        }
    }
    
    func updateRevengeMode(currentTime: Double) {
        let revengeModeEnabled = UserDefaults.standard.bool(forKey: "revengeModeEnabled")
        if !revengeModeEnabled {
            revengeActive = false
            return
        }
        if revengeActive && currentTime >= revengeEndTime {
            revengeActive = false
        }
    }
    
    func canActivateRevenge() -> Bool {
        let revengeModeEnabled = UserDefaults.standard.bool(forKey: "revengeModeEnabled")
        return revengeModeEnabled && combo >= revengeThreshold && !revengeActive
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
    
    func getHealthBarColor() -> String {
        if health > 0.66 {
            return "green"
        } else if health > 0.33 {
            return "yellow"
        } else {
            return "red"
        }
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
        // Performance-based reward: balanced by accuracy, score, combo, difficulty
        let accuracy = totalNotes > 0 ? Double(notesHit) / Double(totalNotes) : 0.0
        let accuracyFactor = max(0.5, accuracy) // ensure at least 50% factor

        let base: Double = 10.0
        let scoreComponent = Double(score) / 1200.0 // ~0..1000 score -> ~0..0.83
        let comboComponent = Double(maxCombo) / 25.0 // encourages higher combos

        let difficultyMultiplier: Double
        switch difficulty {
        case .easy: difficultyMultiplier = 1.0
        case .medium: difficultyMultiplier = 1.25
        case .hard: difficultyMultiplier = 1.5
        case .extreme: difficultyMultiplier = 2.0
        }

        let rawReward = (base + scoreComponent + comboComponent) * accuracyFactor * difficultyMultiplier
        let clamped = max(5, min(Int(rawReward.rounded()), 250))
        lastCoinsEarned = clamped
        tapCoins += clamped
    }

    func saveProgress() {
        // Local cache
        saveProgressLocal()
        // Cloud sync (fire and forget)
        Task { await ProgressService.shared.save(tapCoins: tapCoins, unlockedSongIDs: unlockedSongIDs) }
    }

    func saveProgressLocal() {
        UserDefaults.standard.set(tapCoins, forKey: tapCoinsKey)
        UserDefaults.standard.set(Array(unlockedSongIDs), forKey: unlockedSongsKey)
        UserDefaults.standard.set(Int(totalXP), forKey: xpKey)
        UserDefaults.standard.set(level, forKey: levelKey)
    }

    func loadProgress() {
        tapCoins = UserDefaults.standard.integer(forKey: tapCoinsKey)
        totalXP = Int64(UserDefaults.standard.integer(forKey: xpKey))
        let storedLevel = UserDefaults.standard.integer(forKey: levelKey)
        level = storedLevel > 0 ? storedLevel : LevelingSystem.level(for: totalXP, thresholds: xpThresholds)
        if let ids = UserDefaults.standard.array(forKey: unlockedSongsKey) as? [String] {
            unlockedSongIDs = Set(ids)
        }
        // Ensure the default song is always unlocked
        unlockedSongIDs.insert("hallelujah")
    }

    func loadProgressCloud() {
        Task { await ProgressService.shared.loadAndMerge(into: self) }
    }

    func reset() {
        score = 0
        combo = 0
        maxCombo = 0
        health = 1.0
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

    @discardableResult
    func awardXP(result: SongResult) -> LevelUpResult {
        let output = LevelingSystem.awardXP(result: result, totalXP: totalXP, thresholds: xpThresholds)
        totalXP = output.totalXP
        level = output.newLevel
        saveProgressLocal()
        return output
    }
}
