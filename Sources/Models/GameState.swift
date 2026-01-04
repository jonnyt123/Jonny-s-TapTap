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
    @Published var revengeActive: Bool = false
    @Published var revengeEndTime: Double = 0
    @Published var difficulty: Difficulty = .medium
    @Published var songID: String = "track3"
    @Published var songTitle: String = "Hallelujah"
    @Published var songChartName: String = "chart"
    
    private let missLimit = 100
    private let revengeThreshold = 30
    private let revengeDuration: Double = 8.0
    private var revengeMultiplier: Int = 2
    private let personalBestKeyPrefix = "personalBest_"

    func registerHit(_ judgement: Judgement) {
        if isFailed { return }
        
        var points = judgement.scoreValue
        
        // Apply multiplier
        points = Int(Double(points) * Double(multiplier))
        
        // Apply revenge bonus
        if revengeActive {
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
        if !revengeActive && combo >= revengeThreshold {
            revengeActive = true
            revengeEndTime = currentTime + revengeDuration
        }
    }
    
    func updateRevengeMode(currentTime: Double) {
        if revengeActive && currentTime >= revengeEndTime {
            revengeActive = false
        }
    }
    
    func canActivateRevenge() -> Bool {
        return combo >= revengeThreshold && !revengeActive
    }

    func setDifficulty(_ difficulty: Difficulty) {
        self.difficulty = difficulty
        loadPersonalBest()
        isNewPersonalBest = false
    }

    func setSong(_ song: SongMetadata) {
        songID = song.id
        songTitle = song.title
        songChartName = song.chartName
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
        loadPersonalBest()
    }
}
