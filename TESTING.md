# RhythmTap Test Suite

Minimal non-regression tests: **unit tests** (XP, economy, beatmap parsing, timing) and **UI baseline tests** (app launch, main screen). No snapshot or third-party test dependencies.

---

## What’s included

### Unit tests (`RhythmTapTests`)

| Area | File | What’s tested |
|------|------|----------------|
| **XP** | `LevelingTests.swift` | Level curve monotonicity, level boundaries, XP formula clamp, canonical XP, level-up at threshold, tier names |
| **Economy** | `EconomyTests.swift` | EconomyConfig prices and purchasability, coin reward clamp and difficulty multipliers, unlock persistence (LocalProfileStore round-trip) |
| **Timing** | `TimingTests.swift` | Song time from raw + offset, spawn timing, hit grade (perfect/great/good/bad/miss), note Y position |
| **Beatmap** | `BeatmapParsingTests.swift` | Chart JSON decode (minimal and optional fields), note types, difficulty, ChartLoader placeholder fallback and availability |

### UI tests (`RhythmTapUITests`)

| Test | Purpose |
|------|--------|
| `testAppLaunches` | App launches and main menu (accessibility id `mainMenu`) appears within 8s |
| `testAppStaysRunning` | App is still running after 2s (no immediate crash) |

---

## Run tests locally

### Xcode

1. Open `RhythmTap.xcodeproj`.
2. **Run all tests:** `Cmd+U`, or **Product → Test**.
3. **Run only unit tests:**  
   **Product → Scheme → Edit Scheme… → Test** → uncheck **RhythmTapUITests** → Close, then `Cmd+U`.
4. **Run one test class or method:** Click the diamond next to the class or method in the Test navigator and choose **Run**.

### Command line

From the project directory (where `RhythmTap.xcodeproj` lives):

```bash
# Build
xcodebuild -scheme RhythmTap \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=17.0' \
  -configuration Debug \
  build

# Unit tests only
xcodebuild -scheme RhythmTap \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=17.0' \
  -configuration Debug \
  -only-testing:RhythmTapTests \
  test

# UI tests only
xcodebuild -scheme RhythmTap \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=17.0' \
  -configuration Debug \
  -only-testing:RhythmTapUITests \
  test
```

Replace `iPhone 16` and `OS=17.0` with a simulator you have installed (e.g. **Xcode → Window → Devices and Simulators** or `xcrun simctl list devices`).

---

## CI

GitHub Actions workflow: **`.github/workflows/ci.yml`**

- **Trigger:** Push / PR to `main` or `master`.
- **Runner:** `macos-14`.
- **Steps:** Build, then run **RhythmTapTests**, then **RhythmTapUITests** (UI tests are `continue-on-error: true` so CI doesn’t fail on simulator flakiness).
- **Destination:** `iPhone 15, OS=17.2` (GitHub `macos-14` image). If your runner has different simulators, edit `.github/workflows/ci.yml` and set the same `-destination` for build and test steps.

No extra dependencies; uses only Xcode and the iOS Simulator.

---

## Requirements

- **Xcode 15+** (Swift 5, iOS 17 SDK).
- **Unit tests:** no special setup.
- **UI tests:** main menu must be reachable and the root view for the menu has `accessibilityIdentifier("mainMenu")` (see `ContentView.swift`).

---

## Adding tests

- **Unit:** Add a new `*Tests.swift` file in **Tests/** and add it to the **RhythmTapTests** target (and to the **Tests** group in the project).
- **UI:** Add test methods in **RhythmTapUITests/RhythmTapUITests.swift**. Use `app.buttons["…"]`, `app.staticTexts["…"]`, or `app.descendants(matching: .any).matching(identifier: "…")` and `waitForExistence(timeout:)` to avoid hard-coded delays where possible.
