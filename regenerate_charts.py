#!/usr/bin/env python3
"""Regenerate beatmaps from audio using onset + beat grid alignment.

- Uses librosa to detect onsets per track.
- Quantizes onsets to the local beat grid (16th notes) derived from beat tracking or provided BPM.
- Assigns lanes based on spectral centroid so percussion-heavy moments map to lower lanes and bright content to higher lanes.
"""
from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import List

import librosa
import numpy as np

ROOT = Path(__file__).resolve().parent
RESOURCES = ROOT / "Resources"


@dataclass
class Song:
    id: str
    title: str
    artist: str
    audio_name: str
    audio_ext: str
    chart_name: str
    lanes: int
    bpm: float
    offset: float = 0.0

    @property
    def audio_path(self) -> Path:
        return RESOURCES / f"{self.audio_name}.{self.audio_ext}"

    @property
    def chart_path(self) -> Path:
        return RESOURCES / f"{self.chart_name}.json"


SONGS: List[Song] = [
    Song("hallelujah", "Hallelujah", "Jonny Thompson", "hallelujah", "wav", "hallelujah", 3, 110),
    Song("crazy_train", "Crazy Train", "Ozzy Osbourne", "crazy_train", "mp3", "crazy_train", 4, 138),
    Song("i_will_not_bow", "I Will Not Bow", "Breaking Benjamin", "i_will_not_bow", "mp3", "i_will_not_bow", 4, 92),
    Song("day_n_nite", "Day 'N' Nite", "Kid Cudi", "day_n_nite", "mp3", "day_n_nite", 4, 139.67),
    Song("blink182_see_you", "See You", "blink-182", "blink182_see_you", "mp3", "blink182_see_you", 3, 100),
    Song("madchild_chainsaw", "Chainsaw", "Madchild ft. Slaine", "madchild_chainsaw", "mp3", "madchild_chainsaw", 3, 95),
    Song("hippie_sabotage_high", "High Enough", "Hippie Sabotage", "hippie_sabotage_high", "m4a", "hippie_sabotage_high", 3, 110),
    Song("mgk_dont_let_me_go", "Don't Let Me Go", "MGk", "mgk_dont_let_me_go", "mp3", "mgk_dont_let_me_go", 4, 120),
    Song("bizzy_banks_fonem", "On Fonem Grave", "Bizzy Banks", "bizzy_banks_fonem", "mp3", "bizzy_banks_fonem", 3, 85),
]


def build_grid(beat_times: np.ndarray, fallback_bpm: float, duration: float) -> np.ndarray:
    """Return a dense 16th-note grid covering the track."""
    if beat_times.size < 2:
        # fallback grid from provided BPM
        beat_period = 60.0 / max(fallback_bpm, 1e-6)
        beat_times = np.arange(0, duration + beat_period, beat_period)
    step_times: List[float] = []
    last_interval = None
    for i, bt in enumerate(beat_times):
        if i + 1 < len(beat_times):
            next_bt = beat_times[i + 1]
        else:
            # extrapolate the last interval
            last_interval = beat_times[-1] - beat_times[-2] if len(beat_times) > 1 else 60.0 / max(fallback_bpm, 1e-6)
            next_bt = bt + last_interval
        interval = max(next_bt - bt, 1e-6)
        subdiv = interval / 4.0  # 16th grid
        for k in range(4):
            step_times.append(bt + k * subdiv)
        last_interval = interval
    # Extend grid to cover the entire song duration so tail sections get notes
    if last_interval is None:
        last_interval = 60.0 / max(fallback_bpm, 1e-6)
    extend_bt = beat_times[-1] if beat_times.size else 0.0
    while extend_bt < duration + last_interval:
        extend_bt += last_interval
        subdiv = last_interval / 4.0
        for k in range(4):
            step_times.append(extend_bt + k * subdiv)
    return np.array(step_times, dtype=float)


def quantize_time(t: float, grid: np.ndarray, tolerance: float = 0.12) -> float | None:
    """Snap time to closest grid point; drop if too far."""
    idx = np.argmin(np.abs(grid - t))
    snapped = float(grid[idx])
    if abs(snapped - t) <= tolerance:
        return snapped
    return None


def lane_from_centroid(centroid: float, sr: int, lanes: int, onset_strength: float = 0.5, frame_index: int = 0) -> int:
    """Map spectral centroid + energy to a lane index with light round-robin rotation.
    
    Uses centroid to bias across lanes based on frequency content,
    with minimal round-robin for slight variation.
    """
    # Spectral centroid bias: distribute across all lanes based on frequency
    norm = float(np.clip(centroid / (sr / 2.0), 0.0, 1.0))
    centroid_lane = norm * (lanes - 1)
    
    # Light round-robin from frame index for subtle variation
    rr_lane = frame_index % lanes
    
    # Blend: 80% centroid (natural freq-based distribution), 20% round-robin (subtle variation)
    blended = (0.8 * centroid_lane) + (0.2 * rr_lane)
    lane = int(round(blended)) % lanes
    return int(np.clip(lane, 0, lanes - 1))


def build_notes(song: Song) -> list[dict]:
    if not song.audio_path.exists():
        raise FileNotFoundError(f"Missing audio for {song.title}: {song.audio_path}")

    y, sr = librosa.load(song.audio_path.as_posix(), sr=44100)
    duration = len(y) / sr

    # Onset envelope and detection
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    onset_frames = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, backtrack=True)
    onset_times = librosa.frames_to_time(onset_frames, sr=sr)

    # Beat tracking
    tempo, beat_frames = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr, start_bpm=song.bpm)
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)
    grid = build_grid(beat_times, fallback_bpm=song.bpm, duration=duration)

    # Spectral centroid (for lane decisions)
    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]

    notes: list[dict] = []
    placed_times: list[float] = []
    env_mean, env_std = float(np.mean(onset_env)), float(np.std(onset_env))
    note_count = 0  # Track for frame-based round-robin

    for frame_idx, (frame, raw_time) in enumerate(zip(onset_frames, onset_times)):
        snapped = quantize_time(raw_time, grid)
        if snapped is None:
            continue

        # Debounce near-duplicates
        if placed_times and abs(snapped - placed_times[-1]) < 0.08:
            continue

        # Lane mapping with improved distribution
        c_val = centroid[frame] if frame < len(centroid) else centroid[-1]
        env_str = onset_env[frame] if frame < len(onset_env) else env_mean
        lane = lane_from_centroid(c_val, sr, song.lanes, env_str, note_count)
        note_count += 1

        # Note type: strong peaks become holds occasionally, very bright peaks become shakes
        strength = onset_env[frame] if frame < len(onset_env) else env_mean
        note_type = "tap"
        duration_val = None
        if strength > env_mean + 2.5 * env_std and song.lanes >= 3:
            note_type = "hold"
            duration_val = 0.35
        elif c_val > (sr * 0.35) and strength > env_mean + 1.5 * env_std:
            note_type = "shake"

        notes.append({
            "id": str(uuid.uuid4()),
            "time": round(snapped + song.offset, 3),
            "lane": lane,
            "type": note_type,
            **({"duration": duration_val} if duration_val else {}),
        })
        placed_times.append(snapped)

    # Ensure sorted and unique (just in case)
    notes.sort(key=lambda n: n["time"])
    deduped: list[dict] = []
    for note in notes:
        if deduped and abs(note["time"] - deduped[-1]["time"]) < 0.01 and note["lane"] == deduped[-1]["lane"]:
            continue
        deduped.append(note)

    return deduped


def regenerate(song: Song) -> None:
    print(f"\nProcessing {song.title} ({song.audio_path.name})...")
    notes = build_notes(song)
    if not notes:
        raise RuntimeError(f"No notes detected for {song.title}")

    chart = {
        "songName": song.title,
        "artist": song.artist,
        "bpm": float(song.bpm),
        "offset": float(song.offset),
        "lanes": song.lanes,
        "notes": notes,
    }

    song.chart_path.write_text(json.dumps(chart, indent=2))
    print(f"  Wrote {len(notes)} notes -> {song.chart_path}")


def main() -> None:
    for song in SONGS:
        regenerate(song)


if __name__ == "__main__":
    main()
