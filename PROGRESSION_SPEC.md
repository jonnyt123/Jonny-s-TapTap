# Progression system spec

RhythmTap uses a **level-based progression** that feels similar to classic mobile rhythm games (clear goals, visible XP, ranks, and rewards) while using original naming, formulas, and UI.

---

## Goals

- **Satisfying loop:** Play song → see XP breakdown → fill level bar → earn Tap Coins and unlocks.
- **Skill and effort matter:** Difficulty, accuracy, combo, and song length all contribute to XP.
- **Readable progress:** Tier names (ranks) and a 1–99 level curve give a sense of advancement.
- **Rewards:** Tap Coins per song (performance-based); coins unlock songs. Level is identity/prestige only (no paywall by level).

---

## XP formula (original)

XP per song is computed as:

```
totalXP = round( base × accuracyFactor × comboFactor × lengthFactor × gradeBonus )
```

- **Base (by difficulty):** Easy 120, Normal 180, Hard 260, Expert 360. Harder charts grant more base XP.
- **Accuracy factor:** `0.5 + 0.5 × (accuracyPercent/100)`. Range 0.5–1.0 so low accuracy still yields some XP.
- **Combo factor:** `1.0 + min(maxCombo / 200, 0.6)`. Rewards sustained play; cap 0.6 so combo doesn’t dominate.
- **Length factor:** `0.7 + min(totalNotes / 400, 0.8)`. Longer charts (more notes) give more XP; cap so one 2000-note song doesn’t dwarf others.
- **Grade bonus:** S +18%, A +10%, B +5%, C 0%, D −8%, F −15%. Multiplier applied last.

Result is clamped to **min 30, max 800** XP per song. All constants are tuned so typical play (medium difficulty, 85% accuracy, some combo) lands in the 80–250 XP range.

---

## Level curve

- **Levels 1–99.** Same power curve as before: `thresholds[level]` = XP required to reach that level (level 1 = 0 XP).
- **Max total XP** to reach level 99 is 13M (unchanged). Early levels are fast; later levels take more play.
- **Deterministic:** Same `SongResult` always yields same XP; level is purely `totalXP` vs thresholds.

---

## Tiered ranks (original names)

Ranks are labels for level bands (no mechanical effect):

| Levels | Rank name   |
|--------|-------------|
| 1–12   | Rookie      |
| 13–26  | Striker     |
| 27–42  | Virtuoso    |
| 43–62  | Ace         |
| 63–80  | Master      |
| 81–99  | Legend      |

Shown on the results screen and profile (e.g. “Striker · Lv.18”).

---

## Post-song flow

1. **Grade + stats** (existing): Grade, score, accuracy, combo, notes hit.
2. **Tap Coins** (existing): “+N Tap Coins” when applicable.
3. **XP breakdown (new):** Rows for Base, Accuracy, Combo, Length, Grade → **Total +N XP**.
4. **Level progress:** Bar and “Lv.X” with optional rank; fill bar by gained XP.
5. **Level-up:** When `didLevelUp` is true, bar fills to 100%, then level and bar update to new level and progress. Optional “Level up! Rank: Striker” style message.

No separate “level up” screen unless we add a minimal modal; current inline level bar + optional one-line level-up text is enough for a clean feel.

---

## Rewards

- **Tap Coins:** Awarded on song complete (existing formula: accuracy, score, combo, difficulty). Used to unlock songs in the Shop. No change to coin math here.
- **Unlocks:** Songs are unlocked by purchase (coins) or by being in the default set. Level does not gate songs; it’s prestige only.

---

## Migration for existing players

- **Stored data:** We keep `xpTotal` and `level` in account state. No schema change.
- **Thresholds:** We keep the same level curve (power 2.2, max 99, 13M XP). So existing `xpTotal` still maps to the same level.
- **New formula:** Only *new* XP gains use the new formula (difficulty, accuracy, combo, length, grade). Existing `xpTotal` is not recomputed.
- **Effect:** Existing players keep their level and total XP; future play uses the new breakdown and formula. No one loses level or XP.
- **Optional migration step:** On first launch after the update, the app can leave `xpTotal` and `level` as-is. Level is always recomputed from `level(for: totalXP, thresholds)` when displayed, so if we ever change thresholds we could run a one-time migration: e.g. `xpTotal = min(currentXP, newThresholds[level])` to preserve effective level when moving to a new curve.

---

## Integration

- **GameState / AccountManager:** Still call `awardXP(result)` after song complete; `SongResult` gains `totalNotes` (and optional `songDurationSeconds`) for the length factor.
- **ResultsView:** Builds `SongResult` with `totalNotes: gameState.totalNotes`, then shows `LevelUpResult` with optional `xpBreakdown` and rank.
- **LevelingUI:** `LevelBadge` can show “Lv.X” and optionally rank; progress bar unchanged. New helper: `ProgressionTier.rankName(for: level)`.

---

## Unit tests

- **XP formula:** For fixed `SongResult`, assert `xpForResult` is in [30, 800] and matches hand-computed value for one canonical result.
- **Breakdown:** Assert `base + accuracy + combo + length + grade` (or the stored components) equals `xpGained`.
- **Level boundaries:** Level 1 at 0 XP, level 99 at max XP; one test that crossing a threshold yields `didLevelUp == true`.
- **Tiers:** Assert rank name for levels 1, 13, 27, 43, 63, 81.
