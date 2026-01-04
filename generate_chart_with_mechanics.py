#!/usr/bin/env python3
"""
Generate a rhythm game chart with tap, shake, and hold notes.
Based on audio analysis of track 3.wav
"""

import json
import uuid
import numpy as np
from librosa import load, stft
from librosa.onset import onset_detect
from scipy.signal import butter, sosfilt
import os

AUDIO_FILE = "Resources/track.wav"
OUTPUT_FILE = "Resources/chart.json"

def butter_filter(data, freq_range, sr):
    """Apply butterworth filter to isolate frequency band"""
    low_freq, high_freq = freq_range
    # Ensure valid frequency range
    low_freq = max(low_freq, 1)  # Minimum 1 Hz
    high_freq = min(high_freq, sr / 2 - 1)  # Maximum just below Nyquist
    
    low_norm = low_freq / (sr / 2)
    high_norm = high_freq / (sr / 2)
    
    sos = butter(4, [low_norm, high_norm], btype='band', output='sos')
    return sosfilt(sos, data)

def detect_onsets(audio, sr, freq_range=None):
    """Detect note onsets in audio, optionally filtered to frequency range"""
    if freq_range:
        audio = butter_filter(audio, freq_range, sr)
    
    # Use onset detection with dynamic thresholding
    onset_frames = onset_detect(y=audio, sr=sr, units='time', backtrack=True)
    return onset_frames

def generate_chart():
    """Main chart generation function"""
    
    if not os.path.exists(AUDIO_FILE):
        print(f"Error: {AUDIO_FILE} not found")
        return
    
    # Load audio
    print(f"Loading {AUDIO_FILE}...")
    y, sr = load(AUDIO_FILE, sr=None)
    duration = len(y) / sr
    print(f"Audio loaded: {duration:.2f}s at {sr}Hz")
    
    # Detect bass (0-100 Hz) and snare (3000-8000 Hz)
    print("Analyzing frequency bands...")
    bass_onsets = detect_onsets(y, sr, freq_range=(0, 100))
    snare_onsets = detect_onsets(y, sr, freq_range=(3000, 8000))
    
    print(f"Bass onsets detected: {len(bass_onsets)}")
    print(f"Snare onsets detected: {len(snare_onsets)}")
    
    # Create notes
    notes = []
    lane_rotation = [0, 1, 2]
    lane_idx = 0
    
    # Add bass notes (mostly taps, some doubles)
    bass_step = 1  # Use every bass onset
    for i, onset_time in enumerate(bass_onsets[1::bass_step]):  # Skip first
        # Occasionally make double-tap notes (same timestamp, different lanes)
        if i % 4 == 0:  # Every 4th bass note becomes a double-tap
            for j in range(2):
                lane = lane_rotation[(lane_idx + j) % 3]
                notes.append({
                    "id": str(uuid.uuid4()),
                    "time": float(onset_time),
                    "lane": lane,
                    "type": "tap"
                })
            lane_idx = (lane_idx + 2) % 3
        else:
            lane = lane_rotation[lane_idx % 3]
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "tap"
            })
            lane_idx = (lane_idx + 1) % 3
    
    # Add snare notes (mostly singles, some shakes)
    snare_step = 1
    for i, onset_time in enumerate(snare_onsets[1::snare_step]):  # Skip first
        # Occasionally make shake notes (every 6th snare)
        if i % 6 == 3:
            lane = lane_rotation[lane_idx % 3]
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "shake"
            })
        # Occasionally make hold notes
        elif i % 8 == 5:
            lane = lane_rotation[lane_idx % 3]
            # Hold for 0.3-0.5 seconds
            hold_duration = 0.4
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "hold",
                "duration": hold_duration
            })
        else:
            lane = lane_rotation[lane_idx % 3]
            notes.append({
                "id": str(uuid.uuid4()),
                "time": float(onset_time),
                "lane": lane,
                "type": "tap"
            })
        lane_idx = (lane_idx + 1) % 3
    
    # Filter notes that are too close together (within 0.1s)
    filtered_notes = []
    for note in sorted(notes, key=lambda n: n["time"]):
        if filtered_notes and abs(note["time"] - filtered_notes[-1]["time"]) < 0.1:
            continue
        filtered_notes.append(note)
    
    # Limit to reasonable count
    final_notes = filtered_notes[:1000]
    final_notes.sort(key=lambda n: n["time"])
    
    # Create chart
    chart = {
        "songName": "Track 3",
        "bpm": 110,
        "offset": 0,
        "lanes": 3,
        "notes": final_notes
    }
    
    # Write to file
    print(f"Writing {len(final_notes)} notes to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(chart, f, indent=2)
    
    # Print statistics
    tap_count = sum(1 for n in final_notes if n.get("type") == "tap")
    shake_count = sum(1 for n in final_notes if n.get("type") == "shake")
    hold_count = sum(1 for n in final_notes if n.get("type") == "hold")
    
    print(f"\nChart generated successfully!")
    print(f"Total notes: {len(final_notes)}")
    print(f"  - Tap notes: {tap_count}")
    print(f"  - Shake notes: {shake_count}")
    print(f"  - Hold notes: {hold_count}")
    print(f"Coverage: {final_notes[-1]['time']:.2f}s / {duration:.2f}s")

if __name__ == "__main__":
    generate_chart()
