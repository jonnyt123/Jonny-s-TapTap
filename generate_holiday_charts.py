#!/usr/bin/env python3
"""Generate Holiday charts for all difficulties using frequency-band onsets."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple

import librosa
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parent
RESOURCES = ROOT / "Resources"


@dataclass(frozen=True)
class Band:
    name: str
    freq: Tuple[float, float]


BANDS = {
    "kick": Band("kick", (20.0, 120.0)),
    "snare": Band("snare", (1500.0, 5000.0)),
    "hats": Band("hats", (6000.0, 12000.0)),
    "rhythm": Band("rhythm", (200.0, 1200.0)),
    "bass": Band("bass", (60.0, 250.0)),
    "fills": Band("fills", (800.0, 2500.0)),
    "lead": Band("lead", (1200.0, 3800.0)),
}


def bandpass(y: np.ndarray, sr: int, low: float, high: float) -> np.ndarray:
    nyq = sr / 2.0
    low = max(low, 1.0)
    high = min(high, nyq - 1.0)
    sos = butter(4, [low / nyq, high / nyq], btype="band", output="sos")
    return sosfilt(sos, y)


def onset_times(y: np.ndarray, sr: int, band: Band) -> np.ndarray:
    filtered = bandpass(y, sr, band.freq[0], band.freq[1])
    onset_env = librosa.onset.onset_strength(y=filtered, sr=sr)
    frames = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, backtrack=True)
    return librosa.frames_to_time(frames, sr=sr)


def build_grid(beat_times: np.ndarray, bpm: float, duration: float) -> np.ndarray:
    if beat_times.size < 2:
        beat_period = 60.0 / max(bpm, 1e-6)
        beat_times = np.arange(0, duration + beat_period, beat_period)
    step_times: List[float] = []
    last_interval = None
    for i, bt in enumerate(beat_times):
        if i + 1 < len(beat_times):
            next_bt = beat_times[i + 1]
        else:
            last_interval = beat_times[-1] - beat_times[-2] if len(beat_times) > 1 else 60.0 / max(bpm, 1e-6)
            next_bt = bt + last_interval
        interval = max(next_bt - bt, 1e-6)
        subdiv = interval / 4.0
        for k in range(4):
            step_times.append(bt + k * subdiv)
        last_interval = interval
    if last_interval is None:
        last_interval = 60.0 / max(bpm, 1e-6)
    extend_bt = beat_times[-1] if beat_times.size else 0.0
    while extend_bt < duration + last_interval:
        extend_bt += last_interval
        subdiv = last_interval / 4.0
        for k in range(4):
            step_times.append(extend_bt + k * subdiv)
    return np.array(step_times, dtype=float)


def quantize(times: Iterable[float], grid: np.ndarray, tolerance: float) -> List[float]:
    snapped: List[float] = []
    for t in times:
        idx = int(np.argmin(np.abs(grid - t)))
        q = float(grid[idx])
        if abs(q - t) <= tolerance:
            snapped.append(q)
    return snapped


def sample_times(times: List[float], step: int) -> List[float]:
    if step <= 1:
        return times
    return times[::step]


def add_notes(
    notes: List[dict],
    times: Iterable[float],
    lane: int,
    min_gap: float,
    alternate_lanes: Tuple[int, int] | None = None,
) -> None:
    last_time_by_lane = {0: -999, 1: -999, 2: -999, 3: -999}
    alt_state = 0
    for t in sorted(times):
        if alternate_lanes:
            lane = alternate_lanes[alt_state % 2]
            alt_state += 1
        if t - last_time_by_lane.get(lane, -999) < min_gap:
            continue
        notes.append({
            "id": str(uuid.uuid4()),
            "time": round(t, 3),
            "lane": lane,
            "type": "tap",
        })
        last_time_by_lane[lane] = t


def dedupe_notes(notes: List[dict], min_gap: float) -> List[dict]:
    notes_sorted = sorted(notes, key=lambda n: (n["time"], n["lane"]))
    result: List[dict] = []
    last_time_by_lane = {0: -999, 1: -999, 2: -999, 3: -999}
    for note in notes_sorted:
        t = note["time"]
        lane = note["lane"]
        if t - last_time_by_lane.get(lane, -999) < min_gap:
            continue
        result.append(note)
        last_time_by_lane[lane] = t
    return result


def limit_simultaneous_notes(notes: List[dict], max_notes: int = 2) -> List[dict]:
    """Limit chords at the same time to avoid triple/quad notes."""
    buckets: dict[float, List[dict]] = {}
    for note in notes:
        key = round(float(note["time"]), 3)
        buckets.setdefault(key, []).append(note)
    filtered: List[dict] = []
    for time_key in sorted(buckets.keys()):
        lane_sorted = sorted(buckets[time_key], key=lambda n: n["lane"])
        filtered.extend(lane_sorted[:max_notes])
    return sorted(filtered, key=lambda n: (n["time"], n["lane"]))


def main() -> None:
    audio_name = "Green Day - Holiday [Official Music Video]"
    audio_path = RESOURCES / f"{audio_name}.mp3"
    if not audio_path.exists():
        raise FileNotFoundError(f"Missing audio: {audio_path}")

    y, sr = librosa.load(audio_path.as_posix(), sr=44100)
    duration = len(y) / sr
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    bpm_raw, beat_frames = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr, start_bpm=146.0)
    bpm_val = float(bpm_raw.item()) if isinstance(bpm_raw, np.ndarray) else float(bpm_raw)
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)
    grid = build_grid(beat_times, bpm_val, duration)

    raw = {name: onset_times(y, sr, band) for name, band in BANDS.items()}
    snapped = {name: quantize(times, grid, tolerance=0.12) for name, times in raw.items()}

    charts = {}

    # Easy: kick + snare only.
    easy_notes: List[dict] = []
    add_notes(easy_notes, sample_times(snapped["kick"], 3), lane=0, min_gap=0.28)
    add_notes(easy_notes, sample_times(snapped["snare"], 3), lane=1, min_gap=0.28)
    charts["easy"] = limit_simultaneous_notes(dedupe_notes(easy_notes, min_gap=0.26))

    # Medium: add hats + rhythm guitar.
    medium_notes: List[dict] = []
    add_notes(medium_notes, sample_times(snapped["kick"], 3), lane=0, min_gap=0.24)
    add_notes(medium_notes, sample_times(snapped["snare"], 3), lane=1, min_gap=0.24)
    add_notes(medium_notes, sample_times(snapped["hats"], 4), lane=2, min_gap=0.22)
    add_notes(medium_notes, sample_times(snapped["rhythm"], 3), lane=3, min_gap=0.22)
    charts["medium"] = limit_simultaneous_notes(dedupe_notes(medium_notes, min_gap=0.22))

    # Hard: add bass + fills.
    hard_notes: List[dict] = []
    add_notes(hard_notes, sample_times(snapped["kick"], 2), lane=0, min_gap=0.2)
    add_notes(hard_notes, sample_times(snapped["snare"], 2), lane=1, min_gap=0.2)
    add_notes(hard_notes, sample_times(snapped["hats"], 3), lane=2, min_gap=0.18)
    add_notes(hard_notes, sample_times(snapped["rhythm"], 3), lane=3, min_gap=0.18)
    add_notes(hard_notes, sample_times(snapped["bass"], 3), lane=0, min_gap=0.18)
    add_notes(hard_notes, sample_times(snapped["fills"], 2), lane=2, min_gap=0.18)
    charts["hard"] = limit_simultaneous_notes(dedupe_notes(hard_notes, min_gap=0.18))

    # Extreme: lead riffs, syncopation, quick alternation.
    extreme_notes: List[dict] = []
    add_notes(extreme_notes, sample_times(snapped["kick"], 2), lane=0, min_gap=0.16)
    add_notes(extreme_notes, sample_times(snapped["snare"], 2), lane=1, min_gap=0.16)
    add_notes(extreme_notes, sample_times(snapped["hats"], 2), lane=2, min_gap=0.14)
    add_notes(extreme_notes, sample_times(snapped["rhythm"], 2), lane=3, min_gap=0.14)
    add_notes(extreme_notes, sample_times(snapped["bass"], 2), lane=0, min_gap=0.14)
    add_notes(extreme_notes, sample_times(snapped["fills"], 2), lane=2, min_gap=0.14)
    add_notes(extreme_notes, sample_times(snapped["lead"], 2), lane=3, min_gap=0.14, alternate_lanes=(2, 3))
    charts["extreme"] = limit_simultaneous_notes(dedupe_notes(extreme_notes, min_gap=0.14))

    for difficulty, notes in charts.items():
        chart = {
            "songName": "Holiday",
            "artist": "Green Day",
            "bpm": float(round(bpm_val, 2)),
            "offset": 0.0,
            "lanes": 4,
            "notes": notes,
        }
        output_path = RESOURCES / f"green_day_holiday_{difficulty}.json"
        output_path.write_text(json.dumps(chart, indent=2))
        print(f"Wrote {difficulty}: {len(notes)} notes -> {output_path.name}")


if __name__ == "__main__":
    main()
