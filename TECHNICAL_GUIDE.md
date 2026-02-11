# Jonny's TapTap — Technical Guide

This guide summarizes the current game features and systems for developers.

## Core Stack
- Swift / SwiftUI for UI
- SpriteKit for gameplay
- AVAudioPlayer for gameplay audio
- AVAudioEngine (Editor) for sample-accurate timing in the beatmap editor

## Gameplay Loop
- Song selection and difficulty selection from the main menu
- Gameplay scene driven by a chart (notes with time, lane, type)
- Notes are spawned ahead of the playhead and move toward the hit line
- Results screen calculates performance and rewards

## Timing Model
- `startMusic()` plays after `startDelay`, `songStartTime` set on first frame
- `songTime = max(0, currentTime - songStartTime)`
- Spawn: `notes[next].time - songTime <= spawnLeadTime`
- Miss: when `delta < -hitWindow`
- Holds complete at `songTime >= note.time + duration`

## Charts / Beatmaps
- JSON chart format in `Resources/*.json`
- Chart loader supports difficulty fallback
- Note types: tap, hold, shake
- 3-lane and 4-lane support with distinct visuals

## Beatmap Editor (User-Generated Charts)
- In-game editor for tap-only notes
- MP3 import via Files app
- Sample-accurate timing using AVAudioEngine + AVAudioPlayerNode clock
- Autosave to Documents
- User beatmaps loadable from the main menu

## Main Menu
- Song list with unlocked songs and user beatmap entry
- Difficulty selection and Shop access
- Leaderboards button (Game Center)
- Beatmap Editor entry

## Shop / Unlocks
- Unlock songs using Tap Coins
- GameState persists unlocked songs

## Progression
- Tap Coins awarded at song completion
- XP + Level system (max level 99, cap at 13,000,000 total XP)
- Level progress shown on main menu and results

## Game Center
- Auth on launch
- Submit scores to difficulty-specific leaderboards
- Present leaderboards and challenge flow via Game Center UI

## Persistence
- UserDefaults for local state (coins, XP, unlocked songs, settings)
- Documents directory for user beatmaps and imported audio

## Files of Interest
- `Sources/GameScene.swift` — gameplay rendering and timing
- `Sources/Models/Chart.swift` — chart model + loader
- `Sources/Audio/GameAudioEngine.swift` — gameplay audio
- `Sources/BeatmapEditorView.swift` — editor UI
- `Sources/BeatmapEditorCore.swift` — editor timing + persistence
- `Sources/GameCenter/` — Game Center integration
- `Resources/` — charts + bundled audio
