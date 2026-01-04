#!/usr/bin/env python3
import librosa
import numpy as np
import json
import uuid
from scipy import signal

# Load the audio file
audio_path = "/Users/jonny/RhythmTap/RhythmTap/Sources/Audio/track 3.wav"
y, sr = librosa.load(audio_path, sr=None)

print(f"Audio loaded: {len(y)} samples at {sr} Hz")
print(f"Duration: {librosa.get_duration(y=y, sr=sr):.2f} seconds")

# Split into frequency bands
# Bass: low frequencies (0-100 Hz)
# Snare: high frequencies (3000-8000 Hz)

# Design filters
bass_sos = signal.butter(5, 100, btype='low', fs=sr, output='sos')
snare_sos = signal.butter(5, [3000, 8000], btype='band', fs=sr, output='sos')

# Apply filters
bass_signal = signal.sosfilt(bass_sos, y)
snare_signal = signal.sosfilt(snare_sos, y)

# Detect onsets in each signal
bass_onsets = librosa.onset.onset_detect(y=bass_signal, sr=sr, units='time', backtrack=True)
snare_onsets = librosa.onset.onset_detect(y=snare_signal, sr=sr, units='time', backtrack=True)

print(f"\nBass onsets detected: {len(bass_onsets)}")
print(f"Snare onsets detected: {len(snare_onsets)}")

# Filter by time range (include full song duration, skip first 1 second for intro)
bass_onsets = [t for t in bass_onsets if t > 1.0]
snare_onsets = [t for t in snare_onsets if t > 1.0]

# Keep only every other beat
bass_onsets = bass_onsets[::3]
snare_onsets = snare_onsets[::3]

print(f"Bass onsets (1-100s): {len(bass_onsets)}")
print(f"Snare onsets (1-100s): {len(snare_onsets)}")

# Create notes
notes = []

# Bass notes: double notes (lane 0+1, 1+2, or 0+2)
# Both lanes get the exact same timestamp
bass_patterns = [(0, 1), (1, 2), (0, 2)]
bass_pattern_idx = 0

for onset_time in bass_onsets:
    lanes = bass_patterns[bass_pattern_idx % len(bass_patterns)]
    bass_pattern_idx += 1
    
    # Create two notes at the EXACT same time for double tap
    for lane in lanes:
        note_id = str(uuid.uuid4())
        notes.append({
            "id": note_id,
            "time": round(onset_time, 3),  # Same time for both lanes
            "lane": lane
        })

# Snare notes: single notes (0, 1, or 2)
snare_pattern = [0, 1, 2]
snare_pattern_idx = 0

for onset_time in snare_onsets:
    lane = snare_pattern[snare_pattern_idx % len(snare_pattern)]
    snare_pattern_idx += 1
    
    note_id = str(uuid.uuid4())
    notes.append({
        "id": note_id,
        "time": round(onset_time, 3),
        "lane": lane
    })

# Sort notes by time
notes.sort(key=lambda n: n['time'])

print(f"\nTotal notes created: {len(notes)}")
print(f"Bass notes (double taps): {len(bass_onsets) * 2}")
print(f"Snare notes (single taps): {len(snare_onsets)}")

# Show sample
print("\nFirst 20 notes (by time):")
for i, note in enumerate(notes[:20]):
    print(f"  {i+1}: {note['time']:.3f}s -> Lane {note['lane']}")

# Create the chart
chart = {
    "songName": "Track 3",
    "bpm": 110,
    "offset": 0.0,
    "lanes": 3,
    "notes": notes
}

# Write to JSON
output_path = "/Users/jonny/RhythmTap/RhythmTap/Resources/chart.json"
with open(output_path, 'w') as f:
    json.dump(chart, f, indent=2)

print(f"\nChart saved to {output_path}")
