# RhythmTap - Quick Start & Feature Guide

## 🎮 How to Play

### Main Menu
1. **Difficulty Selection**: Click "DIFFICULTY: MEDIUM" to expand and choose from:
   - **Easy**: Slower notes, less dense
   - **Medium**: Standard difficulty
   - **Hard**: Faster notes, more density
   - **Extreme**: Maximum speed and density
2. **Start Game**: Click "START GAME" to begin

### Gameplay Controls
- **Tap Notes** (Yellow): Tap on the note's lane when it reaches the hit line
- **Shake Notes** (Magenta): Shake your device when the note reaches the hit line
- **Hold Notes** (Cyan): Press and hold the lane for the duration shown by the tail
- **Pause**: Click pause button (top-left) to pause/resume the game
- **Exit**: Use pause menu to return to main menu

### Scoring System
```
Score = (Base Points × Multiplier) × (Revenge Bonus if active)

Base Points:
  - Perfect (±60ms):   1000 pts
  - Great (±120ms):    600 pts
  - Good (±240ms):     300 pts
  - Miss (>240ms):     0 pts

Multiplier:
  - Increases +1x for every 10 consecutive hits
  - Resets to 1x on first miss
  - Displayed in cyan at top center

Revenge Mode:
  - Activated at 30+ combo with device shake
  - Applies 2-4x multiplier for 8 seconds
  - Orange banner appears when active
```

## 📊 HUD Display

### Top Bar (Left to Right)
```
[PAUSE] | SCORE: X | MULTIPLIER: Nx | COMBO: X [🔥]
```

### Health Bar (Bottom)
```
Health: X/100
[================] ← Color coded (Red/Yellow/Green)
```

### Judgement Display (Center)
```
Appears for 0.5 seconds on each hit
"PERFECT" / "GREAT" / "GOOD" / "MISS"
```

### Revenge Mode (When Active)
```
⚡ REVENGE MODE ACTIVE! ⚡
```

## 🎵 Note Types Guide

### Tap Notes (Yellow Circles)
- **Appearance**: Bright yellow circle with glow
- **Interaction**: Single tap when note reaches hit line
- **Timing**: ±240ms hit window
- **Strategy**: Primary note type, easiest to hit

### Shake Notes (Magenta Circles)
- **Appearance**: Magenta/pink circle with glow
- **Interaction**: Device shake/tilt when note reaches hit line
- **Timing**: ±240ms hit window
- **Strategy**: Requires accelerometer input, activates revenge mode

### Hold Notes (Cyan Circles with Tail)
- **Appearance**: Cyan circle with downward tail
- **Interaction**: Press and hold for duration shown by tail length
- **Timing**: Must maintain contact entire duration
- **Strategy**: Challenging mechanic, rewards precision timing

## 🎮 Difficulty Impact

| Aspect | Easy | Medium | Hard | Extreme |
|--------|------|--------|------|---------|
| Note Speed | 70% | 100% | 130% | 160% |
| Note Density | Sparse | Moderate | Dense | Maximum |
| Recommended For | Beginners | Standard | Skilled | Expert |

## 🏆 Health System

- **Starting Health**: 100%
- **Health Depletion**: -1% per missed note
- **Health Recovery**: +1% per successful hit
- **Game Over**: Health reaches 0% (100 missed notes)

### Health Status Colors
```
🟢 Green  (>66%):  Good condition
🟡 Yellow (33-66%): Caution zone
🔴 Red   (<33%):  Critical - high failure risk
```

## ⚡ Revenge Mode

**How to Activate**:
1. Build a combo streak of 30+ consecutive hits
2. When combo ≥ 30, shake your device
3. Revenge mode activates automatically

**Effects**:
- Score multiplier increases to 2-4x
- Orange banner appears
- Duration: 8 seconds
- Works with all note types

**Strategy**:
- Activating revenge mode during high multiplier = massive score boost
- Bonus points apply to all hits during revenge duration

## 🔧 Game State Management

### Combo System
```
Combo Count:
  - Increases +1 on every successful hit
  - Resets to 0 on first miss
  - Displayed top-right with flame emoji (>5 combo)

Multiplier (Based on Combo):
  - Starts at 1x
  - Increases to 2x at 10 consecutive hits
  - Increases to 3x at 20 consecutive hits
  - Increases to 4x at 30 consecutive hits
  - Example: 45 hits = 4x multiplier (45÷10 = 4.5, floor = 4)
```

### Judgement System
```
Perfect      ✓ ≤60ms from note time  → 1000 pts + multiplier
Great        ✓ ≤120ms from note time → 600 pts + multiplier
Good         ✓ ≤240ms from note time → 300 pts + multiplier
Miss         ✗ >240ms or no input   → 0 pts, reset combo, -1% health
```

## 💡 Pro Tips

1. **Tap Notes**: Aim for the center of the yellow circle for Perfect hits
2. **Shake Notes**: Use small, quick shakes rather than large movements
3. **Hold Notes**: Start holding slightly before the note reaches the line
4. **Multiplier Strategy**: Maintain combos to increase multiplier before revenge activation
5. **Health Management**: Avoid getting health too low; recovery is slow
6. **Difficulty Selection**: Start with Medium and work up as you improve
7. **Note Patterns**: Watch for rhythm patterns in the song to predict upcoming notes

## 🎯 Game End Conditions

### Victory
- Complete all 885 notes before combo/health fails
- Final score shown with total stats

### Failure
- Reach 100 missed notes (0% health)
- Failure screen shows:
  - "FAILED!" header
  - Total missed notes count
  - Final score achieved
  - Return to Menu button

## 📱 Mobile Optimization

- **Screen**: Optimized for iPhone portrait orientation
- **Touch**: Forgiving ±240ms hit window for mobile gameplay
- **Accelerometer**: Responsive shake detection
- **Frame Rate**: 60 FPS smooth gameplay
- **Battery**: Efficient particle effects and rendering

## 🐛 Troubleshooting

**Shake notes not registering?**
- Check if accelerometer is enabled in iOS settings
- Try a more vigorous shake movement
- Ensure device is being moved significantly

**Notes seem out of sync?**
- Confirm audio is playing from device speaker, not muted
- Try restarting the game
- Check if device is at full brightness (some lag issues with low brightness)

**Low FPS or stuttering?**
- Close other apps running in background
- Reduce particle effects (would require code modification)
- Try lower difficulty setting initially

## 📞 Feedback & Improvements

For bug reports or feature requests, document:
- Device type and iOS version
- Difficulty level attempted
- Specific note type causing issues
- Score achieved (if applicable)

---

**Version**: 1.0 TTR4 Mechanics  
**Last Updated**: Current session  
**Enjoy the game!** 🎵🎮
