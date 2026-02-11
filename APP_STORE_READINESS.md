# App Store Readiness Report — RhythmTap

**Generated:** Pre-submission audit  
**Status:** Ready for final checklist; a few TODOs remain (see below).

---

## 1. Debug code in Release builds — DONE

- **`AppDebug.swift`** added: `debugLog(_:)` is a no-op in Release (`#if DEBUG`), so no print output or log leakage in production.
- All **`print(...)`** calls in app and framework code have been replaced with **`debugLog(...)`** in:
  - AccountManager, ContentView, GameScene, GameAudioEngine
  - MainMenuScene, SongSelectScene, Chart, ProgressService
  - CloudKitProfileStore, GameCenterPresenter, LeaderboardService
  - BeatmapGenerator
- **Result:** Release builds produce no debug logs.

---

## 2. Info.plist permissions and descriptions — DONE (verify URLs)

- **CFBundleShortVersionString** / **CFBundleVersion**: Set (1.0 / 1). Bump for each submission.
- **ITSAppUsesNonExemptEncryption**: `false` — OK if you use no custom crypto.
- **NSGKFriendListUsageDescription**: Present for Game Center.
- **NSPrivacyPolicyURL**: Present.
- **CFBundleSupportURL**: Present.
- **UIRequiredDeviceCapabilities**: Updated to `armv7` and `gamekit` only. **Microphone** and **bluetooth-le** removed (app uses playback only; no BLE peripherals).
- **NSAppTransportSecurity**: Set to `NSAllowsArbitraryLoads = false` for default HTTPS-only. **MultiplayerBaseURL / MultiplayerWSURL** removed from plist; `Multiplayer.swift` falls back to `http://localhost:8080` when keys are absent.

**TODO before submission:**

- [ ] If you use **multiplayer in production**, add back **MultiplayerBaseURL** and **MultiplayerWSURL** in Info.plist (or via build settings) with **HTTPS/WSS production URLs**, and if needed add an **NSExceptionDomains** entry for that domain (prefer HTTPS to avoid exceptions).
- [ ] Confirm **support** and **privacy** URLs are live and correct.

---

## 3. Entitlements and private API — OK

- **Entitlements** in use: Sign in with Apple, Game Center, iCloud/CloudKit, Push (aps-environment).
- **aps-environment**: Currently `development`. For **Archive for App Store**, Xcode typically sets this to `production`; confirm in the built app’s entitlements after archiving.
- **com.apple.developer.background-tasks.continued-processing.gpu**: Present; ensure it’s required for your use case (e.g. background processing). Remove if unused.
- No **private APIs** or forbidden symbols detected; only standard Swift/UIKit/AVFoundation/CloudKit/GameKit usage.

**TODO:**

- [ ] After archiving, confirm **aps-environment** is `production` in the exported IPA/entitlements.
- [ ] If you do not use background GPU processing, remove that entitlement.

---

## 4. Crash-safe guards — DONE

- **Chart loading** (`Chart.swift`):  
  - **Max chart file size** enforced (5 MB).  
  - **File size** read via `FileManager.attributesOfItem(atPath:)` before loading.  
  - **Data(contentsOf:)** and decode wrapped in `do/catch`; failures return `nil` and use placeholder/fallback chart.
- **Audio** (`GameAudioEngine.swift`):  
  - **Max audio file size** 200 MB before creating `AVAudioPlayer`.  
  - **AVAudioPlayer(contentsOf:)**, **configureAudioSession**, and **prepare** already in `do/catch`; failures set `isReady = false` and return.
- **File I/O**: Chart and audio use `try?` / `do/catch`; no force-unwrap on file or network data in these paths.
- **BeatmapStore.load** (BeatmapEditorCore): Callers use `try?`; consider adding a file size cap for user-picked files if you allow very large imports.

---

## 5. Memory and overdraw — NOTED

- **GameScene**: Note pool preallocated per lane; PERF comments mark allocation-heavy paths (emitters, shape nodes, per-frame arrays). No code changes made; recommendations:
  - Profile with **Instruments (Allocations / Metal)** and **Xcode Metal frame capture** (Overdraw) on a Release build.
  - Keep **Reduce Flashing** / **Background Intensity** options; they can reduce fill and overdraw.
- **TextureManager**: Preload and caching in place; ensure asset catalogs and atlases are used where it makes sense.

**TODO (optional):**

- [ ] Run a Release build under Instruments and fix any major allocation or overdraw hotspots if you see issues on low-end devices.

---

## 6. Pre-submission checklist

Use this before each submission:

### Build and signing

- [ ] **Scheme**: Build for **Release** (or your App Store scheme).
- [ ] **Archive** with “Distribute App” → App Store Connect.
- [ ] **Signing**: Correct team and provisioning; no “development”‑only profiles for the store build.
- [ ] **Entitlements**: Confirm aps-environment and other entitlements match App Store expectations (see §3).

### Info.plist and capabilities

- [ ] **Version and build**: Bump **CFBundleShortVersionString** and/or **CFBundleVersion** as needed.
- [ ] **Multiplayer**: If used in production, set **MultiplayerBaseURL** / **MultiplayerWSURL** (and ATS if HTTP).
- [ ] **Support / Privacy URLs**: Reachable and correct.

### Content and legal

- [ ] **Music / assets**: All bundled tracks and art are licensed for distribution (no unlicensed content).
- [ ] **Age rating**: Questionnaire and in-app content aligned with chosen rating.
- [ ] **Privacy**: App Privacy section in App Store Connect filled; no collection without disclosure.

### Testing

- [ ] **Install from TestFlight** and do a full playthrough (menu → shop → play → results).
- [ ] **Offline**: App degrades gracefully (e.g. no crash when CloudKit or multiplayer unavailable).
- [ ] **Low storage**: Test with low disk space if you write large files (e.g. user beatmaps).

### App Store Connect

- [ ] **Screenshots** and **preview video** for all required device sizes.
- [ ] **Description**, **keywords**, **What’s New**.
- [ ] **Pricing and availability** set.
- [ ] **App-specific password / 2FA** ready if using export/upload from Xcode.

---

## 7. Remaining TODOs summary

| Item | Action |
|------|--------|
| **Multiplayer URLs** | Add production **MultiplayerBaseURL** / **MultiplayerWSURL** to Info.plist (or build config) if you ship multiplayer; use HTTPS/WSS and ATS exception only if needed. |
| **Support / Privacy URLs** | Confirm **CFBundleSupportURL** and **NSPrivacyPolicyURL** are live and correct. |
| **aps-environment** | After archiving, confirm entitlements show **production** for push. |
| **Background GPU entitlement** | Remove if you do not use background GPU processing. |
| **Optional: memory/overdraw** | Profile Release build with Instruments and Metal debugger on target devices. |

---

## 8. Files touched in this pass

- **Added:** `Sources/AppDebug.swift` (debug-only logging).
- **Updated:** `Resources/Info.plist` (capabilities, ATS, multiplayer URL keys removed).
- **Updated:** `Sources/Models/Chart.swift` (max chart file size, safe decode path).
- **Updated:** `Sources/Audio/GameAudioEngine.swift` (max audio file size, all prints → `debugLog`).
- **Updated:** All files that previously used `print(...)` to use `debugLog(...)` (see §1).
- **Updated:** `RhythmTap.xcodeproj/project.pbxproj` (inclusion of `AppDebug.swift`).

Once the TODOs above are done and the checklist is run, the project is in good shape for App Store submission.
