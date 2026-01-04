# RhythmTap - TTR4 Mechanics Implementation Summary

## ✅ Implemented Features

### 1. **Core Gameplay Mechanics**
- **Note Types**: Tap, Shake, and Hold notes
  - **Tap Notes** (Yellow circles): Traditional single-tap notes
  - **Shake Notes** (Magenta circles): Require device acceleration/shake
  - **Hold Notes** (Cyan circles): Long-tail notes requiring sustained touch with visual tail indicator

### 2. **Score Multiplier System**
- **Dynamic Multiplier**: Increases by 1x for every 10 consecutive hits (1x → 2x → 3x → 4x...)
- **Combo-based**: Resets to 1x on first miss after long streaks
- **UI Display**: Shows current multiplier in top HUD (cyan color for emphasis)
- **Scoring Formula**: `Base Points × Multiplier × (Revenge Multiplier if active)`

### 3. **Revenge Mode**
- **Activation**: Triggered automatically when combo reaches 30 consecutive hits + device shake detected
- **Effects**: 
  - Applies 2x-4x multiplier to all scores
  - Lasts 8 seconds
  - Visual indicator banner with flame icon
- **Strategic Mechanic**: Rewards skillful play with high-combo shake activation

### 4. **Shake Detection System**
- **Technology**: CoreMotion accelerometer input
- **Threshold**: Configurable acceleration threshold (1.8g)
- **Debounce**: 0.5s minimum between shake detections
- **Mechanics**: Dedicated shake notes that only register via device acceleration
- **Integration**: Seamlessly integrated with combo streak system

### 5. **Hold Note Mechanics**
- **Touch Duration Tracking**: Tracks sustained finger contact during hold notes
- **Visual Indicators**: 
  - Cyan note head at start
  - Cyan tail extending down (length = duration)
- **Success Condition**: Touch must remain on lane for entire hold duration
- **Hit Detection**: Registers as Perfect if held correctly

### 6. **Difficulty Levels** (3 Main Settings)
```swift
enum Difficulty: String, CaseIterable {
    case easy       // 0.7x speed, every 5th note
    case medium     // 1.0x speed, every 3rd note
    case hard       // 1.3x speed, every 2nd note
    case extreme    // 1.6x speed, all notes
}
```
- **Easy**: Slower notes, reduced density (25% of max notes)
- **Medium**: Standard speed, moderate density (33% of max notes)
- **Hard**: Faster notes, higher density (50% of max notes)
- **Extreme**: Maximum speed, all notes (100% density)
- **Menu Selection**: Players select before each game session
- **Impact**: Affects both note speed and note density

### 7. **Hit Detection System**
- **Lane-based Detection**: Player must tap in correct lane
- **Hit Window**: ±0.24 seconds (24ms buffer for mobile tolerance)
- **Judgement System**:
  - **Perfect** (≤60ms): 1000 points + multiplier bonus
  - **Great** (≤120ms): 600 points + multiplier bonus
  - **Good** (≤240ms): 300 points + multiplier bonus
  - **Miss** (>240ms): 0 points, combo reset, health depletion

### 8. **Health & Failure System**
- **Health Depletion**: Linear scale (100 missed notes = game over)
- **Visual Feedback**: Color-coded health bar
  - Green (>66%): Healthy
  - Yellow (33-66%): Caution
  - Red (<33%): Critical
- **Recovery**: +1% health per successful hit
- **Failure Screen**: Shows missed notes count and final score

### 9. **Enhanced Audio Analysis**
- **Frequency-based Separation**:
  - Bass (1-100 Hz): Detected as tap notes (double-taps every 4th)
  - Snare (3000-8000 Hz): Detected as tap/shake/hold notes
- **Note Generation**: 885 notes generated from track.wav (208.21s coverage)
  - 721 tap notes
  - 111 shake notes
  - 53 hold notes
- **Intelligent Filtering**: Removes notes too close together (<100ms)

### 10. **UI/UX Enhancements**
- **Top HUD Display**:
  - Score (white, top-left)
  - Multiplier (cyan, center)
  - Combo with flame icon (colorized, top-right)
- **Revenge Mode Banner**: Orange alert when active
- **Difficulty Selection Menu**: Easy toggle in main menu
- **Pause System**: Full pause with resume/exit options
- **Failure Screen**: Summary stats with return to menu

### 11. **Visual Polish**
- **Note Rendering**:
  - Color-coded by type (yellow tap, magenta shake, cyan hold)
  - Circular design with glow effects
  - Particle trails during movement
- **Hit Effects**:
  - Colored particle bursts based on judgement quality
  - Scale/fade animations on hit
  - Pulsing hit target circles
- **Background**: Animated gradient with vignette effect
- **Glassmorphic UI**: Modern transparency effects on overlays

## 📊 Chart Statistics

**Current Chart (track.wav)**:
- Duration: 214.88 seconds
- Total Notes: 885
  - 721 Tap Notes (81.5%)
  - 111 Shake Notes (12.5%)
  - 53 Hold Notes (6.0%)
- BPM: 110
- Note Density: ~4.1 notes per second (average)
- Coverage: 97% of song

## 🎮 Gameplay Loop

```
Main Menu 
  ↓
Select Difficulty
  ↓
Game Start (Music + Notes Spawn)
  ↓
Player Input:
  - Tap lane for tap notes
  - Shake device for shake notes
  - Hold finger for hold notes
  ↓
Score Calculation (Base × Multiplier × Revenge)
  ↓
Combo/Health Update
  ↓
Game End (100 misses OR song completion)
  ↓
Failure Screen / Victory
  ↓
Return to Menu
```

## 🔧 Technical Implementation Details

### GameState.swift
- Centralized state management
- Score multiplier calculation
- Revenge mode timer and activation
- Health depletion formula
- Combo tracking

### GameScene.swift (SpriteKit)
- Note spawning with type-specific rendering
- Shake detection via CMMotionManager
- Hold note tracking with duration
- Lane-based hit detection
- Particle effect system

### Chart.swift
- `NoteType` enum (tap, shake, hold)
- `Difficulty` enum with multipliers
- Extended `Note` struct with type and duration
- JSON serialization support

### ContentView.swift
- Difficulty selection integration
- Multiplier and revenge mode UI display
- Game scene lifecycle management
- Pause/Resume mechanics

### MainMenuView.swift
- Difficulty menu with selection feedback
- Animated logo with pulsing glow
- Bound difficulty setting

## 🚀 Future Enhancement Opportunities

1. **XP/Leveling System**: Track cumulative experience points, unlock avatar customization
2. **Multiple Game Modes**: 
   - Arcade Mode (progressive difficulty)
   - Zen Mode (no failure/health)
   - Time Attack (score as much as possible in 60s)
3. **Avatar Customization**: Character skins with unique visual effects
4. **Leaderboards**: Local and online high score tracking
5. **Social Features**: 
   - Share scores on social media
   - Like/rate user performances
   - In-game messaging
6. **Sound Effects**: Hit feedback sounds, score milestone notifications
7. **Advanced Visuals**: Particle system improvements, animated backgrounds
8. **Mobile Optimization**: Further touch responsiveness refinement

## 📝 Development Notes

- **Audio Analysis**: Uses librosa for onset detection and frequency filtering
- **Physics**: Accelerometer-based shake detection with configurable threshold
- **Performance**: Optimized particle effects, efficient note tracking
- **Platform**: iOS 17.0+ with SpriteKit game engine
- **Code Quality**: Type-safe enums, centralized state management, clean separation of concerns

---

**Version**: 1.0 (TTR4-inspired mechanics)  
**Last Updated**: Current session  
**Status**: Core mechanics complete, ready for expansion
