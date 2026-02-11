#!/usr/bin/env python3
"""
Beatmap validation and balancing for RhythmTap.

Scans all *_easy.json, *_medium.json, *_hard.json, *_extreme.json in Resources,
computes per-song per-difficulty metrics, and can output:
- Validation report (density, bursts, lane balance, simultaneity, pacing, difficulty 1-10)
- Auto-scaling recommendations (scroll speed + hit windows per difficulty)
- Optional balance config file (--write-balance-config); NEVER overwrites original beatmaps.

DETERMINISM: All outputs are derived only from chart data; no randomness. Same charts
produce the same report and balance config every run. Original beatmap JSON files are
never modified; only a separate config file may be written when --write-balance-config
is explicitly passed.
"""

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Optional

# Default paths
SCRIPT_DIR = Path(__file__).resolve().parent
RESOURCES_DIR = SCRIPT_DIR / "Resources"

# Sliding window (seconds) for density
DENSITY_WINDOW = 5.0
# Burst: notes in this many seconds
BURST_WINDOW = 1.0
BURST_THRESHOLD_NPS = 4.0  # notes/sec in window = burst
# Simultaneous: notes within this many seconds count as same "chord"
SIMULT_MS = 0.050
# Rest vs intensity: window for "rest" (low) vs "intensity" (high)
PACING_WINDOW = 3.0
REST_NPS_MAX = 0.8
INTENSITY_NPS_MIN = 2.5

DIFFICULTIES = ("easy", "medium", "hard", "extreme")


def discover_charts(resources_dir: Path):
    """Return { song_id: { difficulty: path } }. Song_id = base name without _easy etc."""
    resources_dir = Path(resources_dir)
    if not resources_dir.is_dir():
        return {}
    by_song: dict[str, dict[str, Path]] = defaultdict(dict)
    for p in resources_dir.glob("*.json"):
        name = p.stem
        for d in DIFFICULTIES:
            suffix = f"_{d}"
            if name.endswith(suffix):
                base = name[: -len(suffix)]
                by_song[base][d] = p
                break
    return dict(by_song)


def load_chart(path: Path) -> Optional[dict]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"Warning: could not load {path}: {e}")
        return None
    notes = data.get("notes") or []
    if not isinstance(notes, list):
        return None
    # Normalize: ensure time, lane, type
    out = {
        "songName": data.get("songName", path.stem),
        "bpm": float(data.get("bpm", 120)),
        "offset": float(data.get("offset", 0)),
        "lanes": int(data.get("lanes", 4)),
        "notes": [],
    }
    for n in notes:
        if not isinstance(n, dict):
            continue
        # Support both "time" and procedural "t"
        t_val = n.get("time") if "time" in n else n.get("t")
        if t_val is None:
            continue
        t = float(t_val)
        lane = int(n.get("lane", 0))
        typ = (n.get("type") or "tap").lower() if isinstance(n.get("type"), str) else "tap"
        dur = float(n["duration"]) if n.get("duration") is not None else None
        out["notes"].append({"time": t, "lane": lane, "type": typ, "duration": dur})
    out["notes"].sort(key=lambda x: (x["time"], x["lane"]))
    return out


def compute_density(notes: list, window: float):
    """Average and peak notes/sec, and list of (start_time, nps) for sliding window."""
    if not notes:
        return 0.0, 0.0, []
    times = [n["time"] for n in notes]
    t_min, t_max = min(times), max(times)
    duration = max(t_max - t_min, 1e-6)
    total_notes = len(notes)
    avg_nps = total_notes / duration

    # Sliding window
    nps_samples = []
    step = 0.5
    t = t_min
    peak_nps = 0.0
    while t + window <= t_max + 1e-9:
        count = sum(1 for s in times if t <= s < t + window)
        nps = count / window
        nps_samples.append((t, nps))
        peak_nps = max(peak_nps, nps)
        t += step
    if not nps_samples and total_notes > 0:
        peak_nps = total_notes / max(window, duration)
    return avg_nps, peak_nps, nps_samples


def compute_bursts(notes: list, window: float, threshold_nps: float):
    """Burst sections: [ {start, end, peak_nps, note_count}, ... ]."""
    if not notes:
        return []
    times = [n["time"] for n in notes]
    t_min, t_max = min(times), max(times)
    step = 0.25
    bursts = []
    in_burst = False
    burst_start = None
    burst_peak = 0.0
    burst_count = 0
    t = t_min
    while t <= t_max + 1e-9:
        count = sum(1 for s in times if t <= s < t + window)
        nps = count / window
        if nps >= threshold_nps:
            if not in_burst:
                in_burst = True
                burst_start = t
                burst_peak = nps
                burst_count = count
            else:
                burst_peak = max(burst_peak, nps)
                burst_count = max(burst_count, count)
        else:
            if in_burst and burst_start is not None:
                bursts.append({
                    "start": round(burst_start, 2),
                    "end": round(t + window, 2),
                    "peak_nps": round(burst_peak, 2),
                    "note_count": burst_count,
                })
            in_burst = False
        t += step
    if in_burst and burst_start is not None:
        bursts.append({
            "start": round(burst_start, 2),
            "end": round(t_max, 2),
            "peak_nps": round(burst_peak, 2),
            "note_count": burst_count,
        })
    return bursts


def lane_distribution(notes: list, num_lanes: int):
    """Lane counts and balance score (0 = perfect balance, 1 = max imbalance)."""
    lanes = [0] * max(num_lanes, 1)
    for n in notes:
        lane = max(0, min(n["lane"], len(lanes) - 1))
        lanes[lane] += 1
    total = sum(lanes) or 1
    expected = total / len(lanes)
    # Balance: normalized std dev of lane proportions
    variance = sum((c / total - 1 / len(lanes)) ** 2 for c in lanes) / len(lanes)
    balance_score = min(1.0, math.sqrt(variance) * (2 * len(lanes)))  # 0 = balanced
    return {
        "counts": lanes,
        "balance_score": round(balance_score, 4),
        "expected_per_lane": round(expected, 2),
    }


def simultaneous_frequency(notes: list, window_sec: float):
    """How often notes occur within window_sec (chords)."""
    if len(notes) < 2:
        return {"simultaneous_ratio": 0.0, "max_simultaneous": len(notes), "chord_count": 0}
    times = [n["time"] for n in notes]
    chord_count = 0
    max_simult = 1
    i = 0
    while i < len(times):
        j = i + 1
        while j < len(times) and times[j] - times[i] <= window_sec:
            j += 1
        if j - i > 1:
            chord_count += 1
            max_simult = max(max_simult, j - i)
        i = j
    # Ratio of notes that are part of a chord (within window of another)
    in_chord = 0
    for i, t in enumerate(times):
        if any(i != k and abs(t - times[k]) <= window_sec for k in range(len(times))):
            in_chord += 1
    simultaneous_ratio = in_chord / len(times) if times else 0.0
    return {
        "simultaneous_ratio": round(simultaneous_ratio, 4),
        "max_simultaneous": max_simult,
        "chord_count": chord_count,
    }


def rest_vs_intensity(notes: list, window: float, rest_max: float, intensity_min: float):
    """Proportion of time in rest vs intensity windows."""
    if not notes:
        return {"rest_ratio": 0.0, "intensity_ratio": 0.0, "rest_seconds": 0.0, "intensity_seconds": 0.0}
    times = [n["time"] for n in notes]
    t_min, t_max = min(times), max(times)
    duration = t_max - t_min
    if duration <= 0:
        return {"rest_ratio": 0.0, "intensity_ratio": 0.0, "rest_seconds": 0.0, "intensity_seconds": 0.0}
    step = 0.5
    rest_steps = 0.0
    intensity_steps = 0.0
    t = t_min
    while t + window <= t_max + 1e-9:
        count = sum(1 for s in times if t <= s < t + window)
        nps = count / window
        if nps <= rest_max:
            rest_steps += 1
        elif nps >= intensity_min:
            intensity_steps += 1
        t += step
    rest_sec = rest_steps * step
    intensity_sec = intensity_steps * step
    return {
        "rest_ratio": round(rest_sec / duration, 4) if duration else 0,
        "intensity_ratio": round(intensity_sec / duration, 4) if duration else 0,
        "rest_seconds": round(rest_sec, 2),
        "intensity_seconds": round(intensity_sec, 2),
    }


def difficulty_score(
    avg_nps: float,
    peak_nps: float,
    burst_count: int,
    balance_score: float,
    simultaneous_ratio: float,
    intensity_ratio: float,
) -> float:
    """Normalized difficulty 1-10. Higher = harder."""
    # Heuristic weights (tuned so typical charts land in 1-10)
    s1 = min(10.0, avg_nps * 1.2)           # avg density
    s2 = min(10.0, peak_nps * 0.5)         # peak
    s3 = min(10.0, burst_count * 0.15)     # bursts
    s4 = balance_score * 5                  # lane imbalance adds difficulty
    s5 = simultaneous_ratio * 8            # chords
    s6 = intensity_ratio * 5                # intensity time
    raw = (s1 * 0.25 + s2 * 0.25 + s3 * 0.1 + s4 * 0.1 + s5 * 0.2 + s6 * 0.1)
    return round(min(10.0, max(1.0, raw)), 2)


def analyze_chart(chart: dict) -> dict:
    """Full metrics for one chart."""
    notes = chart["notes"]
    lanes = chart["lanes"]
    avg_nps, peak_nps, nps_samples = compute_density(notes, DENSITY_WINDOW)
    bursts = compute_bursts(notes, BURST_WINDOW, BURST_THRESHOLD_NPS)
    lane_dist = lane_distribution(notes, lanes)
    simult = simultaneous_frequency(notes, SIMULT_MS)
    pacing = rest_vs_intensity(notes, PACING_WINDOW, REST_NPS_MAX, INTENSITY_NPS_MIN)
    score = difficulty_score(
        avg_nps, peak_nps, len(bursts), lane_dist["balance_score"],
        simult["simultaneous_ratio"], pacing["intensity_ratio"],
    )
    duration_sec = (max((n["time"] for n in notes), default=0) - min((n["time"] for n in notes), default=0)) or 1
    return {
        "songName": chart["songName"],
        "bpm": chart["bpm"],
        "lanes": chart["lanes"],
        "note_count": len(notes),
        "duration_seconds": round(duration_sec, 2),
        "density": {
            "average_nps": round(avg_nps, 4),
            "peak_nps": round(peak_nps, 2),
        },
        "bursts": {
            "count": len(bursts),
            "sections": bursts[:10],  # first 10 only in report
        },
        "lane_distribution": lane_dist,
        "simultaneous_notes": simult,
        "pacing": pacing,
        "difficulty_score": score,
    }


def recommend_scaling(metrics: dict, difficulty: str) -> dict:
    """Recommend scroll speed multiplier and hit window preset from metrics."""
    score = metrics["difficulty_score"]
    peak_nps = metrics["density"]["peak_nps"]
    # Scroll: harder charts can use higher base speed; we recommend multiplier by difficulty
    # Game uses: baseNoteSpeed * noteSpeedMultiplier; Difficulty already has .noteSpeedMultiplier (0.7, 1.0, 1.3, 1.6)
    # We output an optional override multiplier (1.0 = no change)
    diff_idx = DIFFICULTIES.index(difficulty) if difficulty in DIFFICULTIES else 1
    # Slight scaling: if chart is very hard for this difficulty, suggest slightly lower speed for playability
    if score > 7 and diff_idx <= 1:
        scroll_mult = 0.9
    elif score > 8 and diff_idx <= 2:
        scroll_mult = 0.95
    else:
        scroll_mult = 1.0
    # Hit window: suggest lenient for high density
    if peak_nps > 6 or score > 8:
        hit_window_preset = "lenient"
    elif score > 6:
        hit_window_preset = "standard"
    else:
        hit_window_preset = "strict"
    return {
        "scroll_speed_multiplier": scroll_mult,
        "hit_window_preset": hit_window_preset,
    }


def run_validation(resources_dir: Path, verbose: bool) -> dict:
    """Scan all charts and return full report."""
    by_song = discover_charts(resources_dir)
    report = {
        "songs": {},
        "summary": {"total_songs": len(by_song), "total_charts": 0},
    }
    for song_id, paths in sorted(by_song.items()):
        report["songs"][song_id] = {}
        for diff in DIFFICULTIES:
            path = paths.get(diff)
            if not path:
                continue
            chart = load_chart(path)
            if not chart:
                continue
            metrics = analyze_chart(chart)
            rec = recommend_scaling(metrics, diff)
            report["songs"][song_id][diff] = {
                "metrics": metrics,
                "recommendations": rec,
            }
            report["summary"]["total_charts"] += 1
            if verbose:
                print(f"  {song_id} / {diff}: notes={metrics['note_count']} score={metrics['difficulty_score']}")
    return report


def write_balance_config(report: dict, output_path: Path, resources_dir: Path) -> None:
    """
    Write a balance config JSON that the game can optionally load.
    Keys: song_id -> difficulty -> scroll_speed_multiplier, hit_window_preset.
    Includes before/after metrics. Does NOT modify any beatmap file.
    """
    config = {
        "_comment": "Optional per-song per-difficulty overrides. App applies these on top of user settings. Never overwrites beatmaps.",
        "version": 1,
        "before_after_summary": {},
        "overrides": {},
    }
    for song_id, diffs in report["songs"].items():
        config["overrides"][song_id] = {}
        config["before_after_summary"][song_id] = {}
        for diff, data in diffs.items():
            m = data["metrics"]
            rec = data["recommendations"]
            config["overrides"][song_id][diff] = {
                "scroll_speed_multiplier": rec["scroll_speed_multiplier"],
                "hit_window_preset": rec["hit_window_preset"],
            }
            # Before = current (no override); after = with recommended scaling (for display only)
            config["before_after_summary"][song_id][diff] = {
                "before": {
                    "difficulty_score": m["difficulty_score"],
                    "scroll_multiplier": 1.0,
                    "hit_window_preset": "standard",
                },
                "after": {
                    "difficulty_score": m["difficulty_score"],
                    "scroll_multiplier": rec["scroll_speed_multiplier"],
                    "hit_window_preset": rec["hit_window_preset"],
                },
            }
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
    print(f"Wrote balance config to {output_path}")


def print_text_report(report: dict) -> None:
    """Human-readable summary to stdout."""
    print("\n=== Beatmap validation report ===\n")
    for song_id, diffs in sorted(report["songs"].items()):
        print(f"## {song_id}")
        for diff in DIFFICULTIES:
            if diff not in diffs:
                continue
            data = diffs[diff]
            m = data["metrics"]
            r = data["recommendations"]
            print(f"  [{diff}] notes={m['note_count']} dur={m['duration_seconds']}s")
            print(f"       density avg={m['density']['average_nps']:.2f} peak={m['density']['peak_nps']:.2f} nps")
            print(f"       bursts={m['bursts']['count']} lane_balance={m['lane_distribution']['balance_score']:.3f} simult_ratio={m['simultaneous_notes']['simultaneous_ratio']:.2f}")
            print(f"       rest_ratio={m['pacing']['rest_ratio']:.2f} intensity_ratio={m['pacing']['intensity_ratio']:.2f}")
            print(f"       difficulty_score={m['difficulty_score']}/10")
            print(f"       recommended: scroll_mult={r['scroll_speed_multiplier']} hit_window={r['hit_window_preset']}")
        print()
    print(f"Total: {report['summary']['total_songs']} songs, {report['summary']['total_charts']} charts\n")


def main():
    ap = argparse.ArgumentParser(
        description="Validate and balance RhythmTap beatmaps. Never overwrites original beatmap files."
    )
    ap.add_argument(
        "--resources",
        type=Path,
        default=RESOURCES_DIR,
        help="Resources directory containing *_easy.json etc.",
    )
    ap.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Write full JSON report to this path.",
    )
    ap.add_argument(
        "--write-balance-config",
        type=Path,
        default=None,
        metavar="PATH",
        help="Write optional balance config (scroll speed + hit windows) to PATH. Does NOT overwrite beatmaps.",
    )
    ap.add_argument(
        "--no-print",
        action="store_true",
        help="Do not print text report to stdout.",
    )
    ap.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose per-chart progress.",
    )
    args = ap.parse_args()

    report = run_validation(args.resources, args.verbose)
    if not args.no_print:
        print_text_report(report)
    if args.report:
        path = Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"Wrote JSON report to {path}")
    if args.write_balance_config:
        write_balance_config(report, args.write_balance_config, args.resources)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
