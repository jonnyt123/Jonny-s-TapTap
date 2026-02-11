# Beatmap validation and balancing

The script `beatmap_validate.py` scans all game beatmaps and produces reports plus optional balance config.

## What it does

- **Scans** every `*_easy.json`, `*_medium.json`, `*_hard.json`, `*_extreme.json` in `Resources/`.
- **Reports** per-song, per-difficulty:
  - Average and peak note density (notes/sec)
  - Burst sections (high density windows)
  - Lane distribution balance
  - Simultaneous notes frequency (chords)
  - Rest vs intensity pacing
  - Normalized difficulty score (1–10)
- **Auto-scaling** recommendations:
  - Scroll speed multiplier per difficulty (when to suggest 0.9/0.95/1.0 for playability)
  - Hit window preset (lenient / standard / strict) from density and score

## Usage

```bash
# Default: print report to stdout, no files written
python3 beatmap_validate.py

# Write full JSON report
python3 beatmap_validate.py --report report.json

# Write optional balance config (scroll + hit windows). Does NOT overwrite any beatmap.
python3 beatmap_validate.py --write-balance-config Resources/beatmap_balance_config.json

# Custom resources path
python3 beatmap_validate.py --resources /path/to/Resources --report out.json
```

## No overwrite of beatmaps

**Original beatmap files are never modified.** The script only:

- Reads existing `*.json` charts.
- Optionally writes a **separate** file when you pass `--write-balance-config`. That file is a config of recommended scroll speed and hit window presets per song/difficulty. The game can optionally load it to apply those overrides; it does not replace or edit any chart JSON.

There is no option to overwrite or rewrite beatmap files. Any future “apply balance” feature would require an explicit flag and would write to **new** files (e.g. a different path or suffix), not over originals.

## Before/after metrics

When you write a balance config, it includes a `before_after_summary` section:

- **Before**: default (scroll 1.0, hit_window standard) and the computed difficulty score.
- **After**: recommended scroll multiplier and hit_window preset for that chart, plus the same difficulty score (score is from the chart only; recommendations don’t change the score).

Use this to compare how suggested scaling would apply without changing any beatmap data.

## Determinism

All outputs are deterministic: same set of chart files always produces the same report and balance config. No randomness is used.

## Balance config format

`beatmap_balance_config.json` (or whatever path you pass to `--write-balance-config`):

- `overrides`: `song_id -> difficulty -> { "scroll_speed_multiplier", "hit_window_preset" }`.
- `before_after_summary`: same keys, with `before` and `after` metrics for comparison.

The game does not load this file by default; you would need to add optional loading in the app (e.g. in `SettingsManager` or when loading a chart) to apply these overrides on top of user settings.
