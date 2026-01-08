#!/usr/bin/env python3
"""
Generate all difficulty charts for Hallelujah
"""

import json
import uuid
import numpy as np
from librosa import load
from librosa.onset import onset_detect
from scipy.signal import butter, sosfilt
import sys

def butter_filter(data, freq_range, sr):
    """Apply butterworth filter to isolate frequency band"""
    low_freq, high_freq = freq_range
    low_freq = max(low_freq, 1)
    high_freq = min(high_freq, sr / 2 - 1)
    
    low_norm = low_freq / (sr / 2)
    high_norm = high_freq / (sr / 2)
    
    sos = butter(4, [low_norm, high_norm], btype='band', output='sos')
    return sosfilt(sos, data)

def detect_onsets(audio, sr, freq_range=None):
    """Detect note onsets in audio"""
    if freq_range:
        audio = butter_filter(audio, freq_range, sr)
    
    onset_frames = onset_detect(y=audio, sr=sr, units='time', backtrack=True)
    return onset_frames

def generate_chart_for_difficulty(audio_file, bpm, lanes, difficulty_name, note_step):
    """Generate a single chart for specific difficulty"""
    
    print(f"\nGenerating {difficulty_name} chart...")
    y, sr = load(audio_file, sr=None)
    duration = len(y) / sr
    
    # Detect bass (20-150 Hz) and snare/hi-hat (2000-8000 Hz)
    bass_onsets = detect_onsets(y, sr, freq_range=(20, 150))
    snare_onsets = detect_onsets(y, sr, freq_range=(2000, 8000))
    
    # Create notes
    notes = []
    lane_rotation = list(range(lanes))
    lane_idx = 0
    
    # Add bass notes (mostly taps)
    for i, onset_time in enumerate(bass_onsets[::note_step]):
        if onset_time < 0.5:  # Skip very early notes
            continue
        
        # Every 4th bass note becomes a double-tap
        if i % 4 == 0 and lanes > 1:
            for j in range(min(2, lanes)):
                lane = lane_rotation[(lane_idx + j) % lanes]
                notes.append({
                    "id": str(uuid.uuid4()),
                    "time": float(onset_time),
                    "lane": lane,
                    "type": "tap"
                })
            lane_idx = (lane_idx + 2) % lanes
        else:
            lane = lane_rotation[lane_idx % lanes]
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "tap"
            })
            lane_idx = (lane_idx + 1) % lanes
    
    # Add snare notes (mix of taps, shakes, holds)
    for i, onset_time in enumerate(snare_onsets[::note_step]):
        if onset_time < 0.5:
            continue
            
        lane = lane_rotation[lane_idx % lanes]
        
        # Vary note types for harder difficulties
        if difficulty_name == "extreme" and i % 5 == 3:
            # Shake notes
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "shake"
            })
        elif difficulty_name in ["hard", "extreme"] and i % 7 == 5:
            # Hold notes
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "hold",
                "duration": 0.4
            })
        else:
            # Regular tap
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "tap"
            })
        
        lane_idx = (lane_idx + 1) % lanes
    
    # Filter notes too close together
    filtered_notes = []
    min_gap = 0.15 if difficulty_name == "extreme" else 0.2
    for note in sorted(notes, key=lambda n: n["time"]):
        if filtered_notes and abs(note["time"] - filtered_notes[-1]["time"]) < min_gap:
            continue
        filtered_notes.append(note)
    
    filtered_notes.sort(key=lambda n: n["time"])
    
    # Create chart
    chart = {
        "songName": "Hallelujah",
        "artist": "Jonny Thompson",
        "bpm": bpm,
        "offset": 0.0,
        "lanes": lanes,
        "notes": filtered_notes
    }
    
    # Write to file
    output_file = f"Resources/hallelujah_{difficulty_name}.json"
    with open(output_file, 'w') as f:
        json.dump(chart, f, indent=2)
    
    # Print statistics
    tap_count = sum(1 for n in filtered_notes if n.get("type") == "tap")
    shake_count = sum(1 for n in filtered_notes if n.get("type") == "shake")
    hold_count = sum(1 for n in filtered_notes if n.get("type") == "hold")
    
    print(f"✓ {output_file}")
    print(f"  Total notes: {len(filtered_notes)}")
    print(f"  - Tap: {tap_count}, Shake: {shake_count}, Hold: {hold_count}")
    print(f"  Coverage: {filtered_notes[-1]['time']:.2f}s / {duration:.2f}s")
    
    return len(filtered_notes)

def main():
    audio_file = "Resources/hallelujah.wav"
    bpm = 110
    lanes = 3
    
    print(f"Generating charts for Hallelujah")
    print(f"Audio: {audio_file}")
    print(f"BPM: {bpm}")
    print(f"Lanes: {lanes}")
    
    # Generate all difficulties
    # note_step controls density: higher = fewer notes
    generate_chart_for_difficulty(audio_file, bpm, lanes, "easy", note_step=5)
    generate_chart_for_difficulty(audio_file, bpm, lanes, "medium", note_step=3)
    generate_chart_for_difficulty(audio_file, bpm, lanes, "hard", note_step=2)
    generate_chart_for_difficulty(audio_file, bpm, lanes, "extreme", note_step=1)
    
    # Also update the base chart
    generate_chart_for_difficulty(audio_file, bpm, lanes, "medium", note_step=3)
    import shutil
    shutil.copy("Resources/hallelujah_medium.json", "Resources/hallelujah.json")
    
    print("\n✅ All charts generated successfully!")

if __name__ == "__main__":
    main()
