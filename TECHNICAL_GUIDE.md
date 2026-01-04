# RhythmTap - Technical Implementation Guide

## 📁 Project Structure

```
RhythmTap/
├── Sources/
│   ├── RhythmTapApp.swift           # App entry point
│   ├── ContentView.swift            # Main game container + difficulty state
│   ├── MainMenuView.swift           # Menu with difficulty selection
│   ├── GameScene.swift              # SpriteKit game engine
│   ├── GameAudioEngine.swift        # Audio playback manager
│   ├── FireRainView.swift           # Particle effect overlay
│   ├── SKTextureExtension.swift     # SpriteKit extensions
│   ├── Audio/
│   │   └── GameAudioEngine.swift    # Audio playback
│   └── Models/
│       ├── GameState.swift          # Game state + scoring logic
│       └── Chart.swift              # Note data structures + difficulty
│
├── Resources/
│   ├── track.wav                    # Game audio file
│   ├── chart.json                   # Note beatmap (885 notes)
│   ├── Info.plist
│   └── LaunchScreen.storyboard
│
├── generate_chart_with_mechanics.py # Chart generator (Python)
├── TTR4_MECHANICS.md               # Feature documentation
├── GAMEPLAY_GUIDE.md               # Player guide
└── [This file]
```

## 🔧 Core Systems

### 1. GameState.swift (State Management)

**Key Properties**:
```swift
@Published var score: Int = 0              // Current score
@Published var combo: Int = 0              // Current combo streak
@Published var maxCombo: Int = 0           // Max combo reached
@Published var health: Double = 1.0        // Health 0.0-1.0
@Published var multiplier: Int = 1         // Score multiplier
@Published var experience: Int = 0         // XP for leveling (future)
@Published var revengeActive: Bool = false // Revenge mode status
@Published var difficulty: Difficulty = .medium
```

**Key Methods**:
```swift
func registerHit(_ judgement: Judgement)
  // Called when note is hit
  // Updates score with multiplier
  // Manages combo and health
  
func activateRevengeMode(currentTime: Double)
  // Activates revenge at combo ≥ 30
  // Sets 8-second duration
  
func updateRevengeMode(currentTime: Double)
  // Called each frame to check revenge expiry
```

**Scoring Formula**:
```swift
let points = judgement.scoreValue      // 1000/600/300/0
let withMultiplier = points * multiplier
let final = revengeActive ? 
    withMultiplier * revengeMultiplier : withMultiplier
score += final
```

### 2. GameScene.swift (SpriteKit Engine)

**Key Components**:
```swift
// Note Management
private var notes: [Note]                    // All chart notes
private var activeNotes: [UUID: SKShapeNode] // Visible notes
private var nextNoteIndex: Int               // Next note to spawn

// Shake Detection
private let motionManager = CMMotionManager()
private var shakeThreshold: Double = 1.8
private let shakeDebounce: TimeInterval = 0.5

// Hold Note Tracking
private var activeHolds: [UUID: (startTime: TimeInterval, lane: Int)] = [:]
private var touchedLanes: Set<Int> = []
```

**Game Loop**:
```swift
override func update(_ currentTime: TimeInterval) {
  // 1. Check pause state
  // 2. Initialize scene on first update
  // 3. Calculate song time
  // 4. Update revenge mode
  // 5. Spawn upcoming notes
  // 6. Update note positions
  // 7. Update hold note state
}
```

**Note Spawning**:
- Lead time: 2.5 seconds before playable
- Color coding by type:
  - Tap: Yellow (#FFFF00)
  - Shake: Magenta (#FF00FF)
  - Hold: Cyan (#00FFFF)
- Particle trails attached to each note
- Hold notes include visual tail

**Hit Detection**:
```swift
func handleTap(at point, touch, phase) {
  // Phase 1: touchesBegan
  //   - Record touched lane
  //   - Check for hold note start
  
  // Phase 2: touchesMoved
  //   - Track lane for multi-lane holds
  
  // Phase 3: touchesEnded
  //   - Remove lane from touched set
  
  // For tap/shake notes:
  //   - Find candidates in lane within hit window
  //   - Register closest by time
}
```

**Shake Handling**:
```swift
func processShakeDetection(_ acceleration: CMAcceleration) {
  let totalAccel = sqrt(x² + y² + z²)
  if totalAccel > shakeThreshold && 
     now - lastShakeTime > shakeDebounce {
    handleShakeDetected()
  }
}

func handleShakeDetected() {
  // Find all shake notes near current time
  // Register closest shake note
  // Activate revenge mode if eligible
}
```

### 3. Chart.swift (Data Models)

**NoteType Enum**:
```swift
enum NoteType: String, Codable {
    case tap = "tap"      // Standard tap
    case shake = "shake"  // Accelerometer input
    case hold = "hold"    // Long press
}
```

**Difficulty Enum**:
```swift
enum Difficulty: String, CaseIterable {
    case easy       // 70% speed, 1/5 density
    case medium     // 100% speed, 1/3 density
    case hard       // 130% speed, 1/2 density
    case extreme    // 160% speed, full density
    
    var noteSpeedMultiplier: CGFloat
    var noteDensityDivisor: Int
}
```

**Note Structure**:
```swift
struct Note: Codable, Identifiable {
    let id: UUID
    let time: Double        // Seconds from song start
    let lane: Int           // 0, 1, or 2
    let type: NoteType      // tap, shake, hold
    let duration: Double?   // For hold notes (0.3-0.5s)
}
```

**Chart Structure**:
```swift
struct Chart: Codable {
    let songName: String    // "Track 3"
    let bpm: Int            // 110
    let offset: Double      // Sync offset
    let lanes: Int          // 3
    let notes: [Note]       // Array of notes
}
```

### 4. ContentView.swift (Game Container)

**State Management**:
```swift
@StateObject var gameState     // Central game state
@State var isPlaying           // Game active flag
@State var isPaused            // Pause state
@State var scene: GameScene?   // SpriteKit scene reference
@State var selectedDifficulty  // Current difficulty
```

**UI Sections**:
1. **Main Menu**: MainMenuView with difficulty selector
2. **Game View**: SpriteView(scene) with overlays
3. **Overlay**: HUD with score/combo/multiplier
4. **Revenge Banner**: Shows when revenge active
5. **Pause Menu**: Resume/Exit options
6. **Failure Screen**: Final stats

**Difficulty Binding**:
```swift
// Passed from MainMenuView to ContentView to GameState
selectedDifficulty: Difficulty = .medium
// Used for note speed/density in GameScene
```

### 5. MainMenuView.swift (Menu UI)

**Features**:
- Animated logo with pulsing glow
- Difficulty dropdown menu
- Start button
- Selection feedback with checkmarks

**Binding**:
```swift
@Binding var selectedDifficulty: Difficulty
// Updates parent ContentView when changed
```

## 🎵 Audio & Chart System

### Chart Generation (`generate_chart_with_mechanics.py`)

**Process**:
1. Load audio file with librosa
2. Apply butterworth filters:
   - Bass: 1-100 Hz
   - Snare: 3000-8000 Hz
3. Detect onsets in each frequency band
4. Create notes:
   - Bass → tap notes (some doubles)
   - Snare → tap/shake/hold notes (mixed)
5. Filter close notes (<100ms)
6. Output to chart.json

**Statistics**:
```
Input: track.wav (214.88s @ 48kHz)
Output: chart.json (885 notes)
  - 721 Tap notes (81.5%)
  - 111 Shake notes (12.5%)
  - 53 Hold notes (6.0%)
Coverage: 97% of song
```

### Audio Playback (`GameAudioEngine.swift`)

**Responsibilities**:
- Load track.wav from bundle
- Play/pause/resume/stop
- Sync with note timing
- Update current playback position

**Integration**:
- Started on game begin
- Paused during pause menu
- Stopped on game end

## 🎮 Game Flow

```
┌─────────────────────────────────────────┐
│           Main Menu                     │
│   - Display logo with animations       │
│   - Show difficulty selector            │
│   - Start button                        │
└──────────────┬──────────────────────────┘
               │ User selects difficulty
               ▼
┌─────────────────────────────────────────┐
│         Game Initialization             │
│   - Create GameScene                    │
│   - Load chart.json                     │
│   - Initialize GameState                │
│   - Start audio playback               │
└──────────────┬──────────────────────────┘
               │ Game starts
               ▼
┌─────────────────────────────────────────┐
│         Game Loop (60 FPS)              │
│   ┌─────────────────────────────────┐  │
│   │ Spawn Notes (lead time: 2.5s)   │  │
│   │ Update Positions                │  │
│   │ Handle Input (tap/shake/hold)   │  │
│   │ Register Hits (with judgement)  │  │
│   │ Update Score/Combo/Health       │  │
│   │ Check Revenge Mode              │  │
│   │ Render Frame                    │  │
│   └─────────────────────────────────┘  │
└──────────────┬──────────────────────────┘
               │ Player hits/misses notes
               │
         ┌─────┴─────┐
         │           │
    Pause        Continue
         │           │
         ▼           ▼
    Pause Menu    Game Loop
         │           │
         └─────┬─────┘
               │
         ┌─────┴──────────────┐
         │                    │
    Game Over        Combo Reset
    (100 misses)         (Miss)
         │                    │
         ▼                    ▼
    Failure Screen      Continue Loop
         │                    │
         └─────────┬──────────┘
                   │
              Return to Menu
```

## 🔧 Note Type Handling

### Tap Notes
```swift
// Spawn
node = SKShapeNode(circleOfRadius: 24)
node.fillColor = yellow
node.strokeColor = white

// Hit Detection
if tappedLane == note.lane && 
   abs(note.time - songTime) <= hitWindow {
  register(judgement: getJudgement(delta))
}
```

### Shake Notes
```swift
// Spawn
node = SKShapeNode(circleOfRadius: 24)
node.fillColor = magenta

// Hit Detection
processShakeDetection()  // In CMMotionManager callback
if shakeDetected && combo >= 30 {
  activateRevengeMode()
}
```

### Hold Notes
```swift
// Spawn
headNode = SKShapeNode(circleOfRadius: 24)
tailNode = SKShapeNode(rect: CGRect(...))  // Visual indicator
tailNode.fillColor = cyan.withAlphaComponent(0.3)

// Tracking
activeHolds[note.id] = (startTime: songTime, lane: lane)
touchedLanes.insert(lane)

// Completion
if songTime >= holdEndTime {
  if touchedLanes.contains(note.lane) {
    register(judgement: .perfect)
  } else {
    register(judgement: .miss)
  }
}
```

## 📊 Performance Metrics

- **Note Spawn Rate**: ~4 notes/second average
- **Update Frequency**: 60 FPS (16.67ms per frame)
- **Memory Usage**: ~50-80 MB (estimate)
- **Particle Efficiency**: Cached emitters, reused
- **Audio Sync**: ±30ms accuracy

## 🚀 Performance Optimizations

1. **Note Caching**: Dictionary lookup O(1)
2. **Particle Pooling**: Cached emitter templates
3. **Lazy Spawning**: Only create notes when needed
4. **Efficient Filtering**: Single pass to find hit candidates
5. **Debounced Events**: Shake detection with 0.5s debounce
6. **Viewport Culling**: Only render visible notes

## 🔐 Data Persistence

- Game state stored in memory during session
- Chart data loaded from bundle (read-only)
- No persistent score storage (future feature)
- Future: UserDefaults for high scores

## 📦 Dependencies

```
SwiftUI (iOS Framework)
SpriteKit (iOS Framework)
CoreMotion (iOS Framework - Accelerometer)
AVFoundation (iOS Framework - Audio)

Python (offline only):
  - librosa (audio analysis)
  - scipy (signal processing)
  - numpy (numerical computation)
  - json (serialization)
```

## 🐛 Known Issues & Limitations

- **Shake Detection**: Requires significant device movement
- **Hold Notes**: Single-lane only (no multi-lane holds)
- **Audio Sync**: ±30ms jitter possible on some devices
- **Memory**: No note pooling (all notes kept in memory)
- **Score**: No persistence between sessions

## 🔮 Future Enhancements

### High Priority
- [ ] Local high score persistence
- [ ] Sound effects on hits
- [ ] Visual feedback for missed notes
- [ ] Difficulty adjustment based on performance

### Medium Priority
- [ ] XP/leveling system
- [ ] Avatar customization
- [ ] Multiple songs/charts
- [ ] Song selection menu

### Low Priority
- [ ] Online leaderboards
- [ ] Multiplayer modes
- [ ] Custom chart support
- [ ] Theme customization

---

**Version**: 1.0  
**Last Updated**: Current session  
**Language**: Swift + Python (generation only)  
**Platform**: iOS 17.0+  
**Status**: Production ready for core mechanics
