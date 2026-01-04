# RhythmTap (iOS SpriteKit)

A lightweight Tap Tap–style rhythm prototype built with SwiftUI + SpriteKit. It uses XcodeGen for project generation.

## Quick start
1. Install XcodeGen (once): `brew install xcodegen`.
2. From this folder, generate the Xcode project: `xcodegen generate`.
3. Open the generated `RhythmTap.xcodeproj` in Xcode.
4. Select an iOS simulator or device and run.

## Add your song
- Drop your audio file into `Resources` and name it `track.m4a` (or `track.wav`).
- Ensure the file is added to the target in Xcode (it will be if it sits in `Resources/`).
- Replace the sample chart in `Resources/chart.json` with timing that matches your song.

### Chart format (`chart.json`)
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
- `time` is in seconds from song start.
- `lane` is zero-indexed.
- `offset` lets you nudge all notes if the audio has silence up front.
- `id` must be a UUID string; you can keep the ones in the sample or generate new ones.

## Gameplay specifics
- 3 lanes by default (change via `lanes` in the chart file).
- Judgements: Perfect (≤50ms), Great (≤100ms), Good (≤160ms), Miss otherwise.
- Score adds a small combo bonus; misses drop health and reset combo.

## Swapping assets/colors
- Lane colors are defined in `GameScene.laneColors`.
- Note speed and hit window live in `GameScene` (`noteSpeed`, `hitWindow`).

If you share your audio file, I can align a proper chart for it.
