# RhythmTap (iOS SpriteKit)

A lightweight Tap Tap–style rhythm game built with SwiftUI + SpriteKit. It uses XcodeGen for project generation.

## Quick Start
1. **Install XcodeGen** (one-time): `brew install xcodegen`
2. **From this folder, generate the Xcode project:** `xcodegen generate`
3. **Open the generated `RhythmTap.xcodeproj` in Xcode**
4. **Select an iOS simulator or device and run**

## 🎵 Available Songs (10 Total)

| Song | Artist | BPM | Lanes | Difficulty |
|------|--------|-----|-------|------------|
| Hallelujah | Jonny Thompson | 110 | 3 | Medium |
| Crazy Train | Ozzy Osbourne | 138 | 4 | Hard |
| I Will Not Bow | Breaking Benjamin | 92 | 4 | Hard |
| Day 'N' Nite | Kid Cudi | 139.67 | 4 | Hard |
| See You | blink-182 | 100 | 3 | Medium |
| Chainsaw | Madchild ft. Slaine | 95 | 3 | Medium |
| High Enough | Hippie Sabotage | 110 | 3 | Medium |
| Don't Let Me Go | MGk | 120 | 4 | Hard |
| On Fonem Grave | Bizzy Banks | 85 | 3 | Easy |
| Remix Revision | Original | 115 | 3 | Medium |

## ⚙️ Gameplay Configuration

**Timing Window:**
- Perfect: ±50ms
- Great: ±80ms (±0.08s)
- Good: ±160ms (±0.16s)
- Miss: Beyond hit window

**Performance:**
- Note Speed: 350 pixels/second
- Spawn Lead Time: 2.8 seconds
- Frame Rate: 120 FPS cap
- Tap Sounds: Polyphonic (up to 8 simultaneous)

## 📝 Game Mechanics

- **3-4 lanes** per song (configurable)
- **Tap notes** - Hit on the beat
- **Shake notes** - Device shake/accelerometer
- **Hold notes** - Press and hold
- **Combo system** - Build multiplier for points
- **Health system** - Misses reduce health
- **Revenge Mode** - Special power-up mechanic

## 📂 Project Structure

```
RhythmTap/
├── Sources/
│   ├── RhythmTapApp.swift         # App entry point
│   ├── MainMenuView.swift         # Song selection UI
│   ├── ContentView.swift          # Game container
│   ├── GameScene.swift            # Core game logic (SpriteKit)
│   ├── Audio/
│   │   └── GameAudioEngine.swift  # Audio playback & tap sounds
│   └── Models/
│       ├── SongLibrary.swift      # Song metadata
│       ├── Chart.swift            # Beatmap format
│       └── GameState.swift        # Game state management
├── Resources/
│   ├── *.mp3, *.m4a, *.wav        # Audio files (12 total)
│   ├── *.json                     # Beatmaps/charts (13 total)
│   ├── *.png                      # Background images
│   ├── Info.plist                 # App configuration
│   └── LaunchScreen.storyboard    # Launch screen
├── project.yml                    # XcodeGen configuration
└── RhythmTap.xcodeproj           # Generated Xcode project
```

## 🎨 Customization

### Change Lane Colors
Edit `GameScene.swift` `laneColors` array:
```swift
private let laneColors: [SKColor] = [
    SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),
    SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1),
    // ... add more colors
]
```

### Adjust Gameplay Difficulty
Modify these in `GameScene.swift`:
```swift
private let hitWindow: Double = 0.16      // Timing window
private let noteSpeed: CGFloat = 350      // Note fall speed
private let spawnLeadTime: Double = 2.8   // Preview time
```

### Add More Songs

**Method 1: Using the Script**
```bash
python3 prepare_songs.py
# Edit SONGS_TO_ADD in the script, add your audio files to ~/Music
xcodegen generate
```

**Method 2: Manual**
1. Copy audio file to `Resources/`
2. Create `songname.json` beatmap:
```json
{
  "songName": "My Song",
  "bpm": 120,
  "offset": 0.0,
  "lanes": 3,
  "notes": [
    { "id": "uuid-here", "time": 1.0, "lane": 0 }
  ]
}
```
3. Add to `SongLibrary.swift`:
```swift
SongMetadata(
    id: "my-song",
    title: "My Song",
    artist: "Artist Name",
    audioName: "my_song",
    audioExtension: "mp3",
    chartName: "my_song",
    lanes: 3,
    bpm: 120,
    primaryColors: [.purple, .blue],
    accent: .cyan
)
```

### Chart Format Details (`*.json`)

```json
{
  "songName": "Song Title",
  "artist": "Artist Name",
  "bpm": 120,
  "offset": 0.0,
  "lanes": 3,
  "notes": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "time": 1.5,
      "lane": 1,
      "type": "tap",
      "duration": null
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "time": 2.0,
      "lane": 0,
      "type": "hold",
      "duration": 1.0
    }
  ]
}
```

- **`time`** - Seconds from song start
- **`lane`** - 0-indexed lane (0 to lanes-1)
- **`type`** - "tap", "shake", or "hold"
- **`duration`** - Hold duration in seconds (hold notes only)
- **`offset`** - Audio delay compensation

## 🔊 Audio Formats Supported

- **MP3** (.mp3)
- **AAC** (.m4a, .m4b)
- **WAV** (.wav)
- **AIFF** (.aiff, .aif)

All formats are handled by AVAudioPlayer with automatic format detection.

## 🎮 Control Scheme

| Action | Control |
|--------|---------|
| Tap note | Tap lane area |
| Shake note | Shake device |
| Hold note | Press and hold lane |
| Pause | Menu button |
| Resume | Resume button |

## 📊 Score System

- **Perfect:** 100 points + combo
- **Great:** 75 points + combo
- **Good:** 50 points
- **Miss:** 0 points - health penalty
- **Combo Multiplier:** Score × (1 + combo/100)

## 📋 Troubleshooting

**No audio playing?**
- Unmute device (not on silent mode)
- Check audio files exist in Resources/
- Verify device volume is up

**Notes not syncing?**
- Adjust `hitWindow` in GameScene.swift
- Check BPM value in chart JSON
- Verify `offset` value in chart

**Low FPS?**
- Reduce particle effects
- Lower `view.preferredFramesPerSecond` in GameScene
- Disable background animations

**Songs not appearing?**
- Run `xcodegen generate`
- Check SongLibrary.swift has all songs
- Verify chart JSON files exist
- Check audioName and audioExtension match files

## 🔄 Version History

- **v2.0** - Full song library integration, beatmap generation, gameplay fine-tuning
- **v1.0** - Initial prototype with basic gameplay mechanics

---

**Status:** ✅ Complete and Ready
**Last Updated:** January 4, 2026

