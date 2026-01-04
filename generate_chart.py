#!/usr/bin/env python3
import librosa
import numpy as np
import json
import uuid

# Load the audio file
audio_path = "/Users/jonny/RhythmTap/RhythmTap/Sources/Audio/track 3.wav"
y, sr = librosa.load(audio_path, sr=None)

# Detect beats using the librosa beat tracking
tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
beat_times = librosa.frames_to_time(beats, sr=sr)

# Get all onsets/note onsets
onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units='time')

print(f"Detected Tempo: {float(tempo):.2f} BPM")
print(f"Number of beats: {len(beat_times)}")
print(f"Number of onsets detected: {len(onset_frames)}")
print(f"Audio duration: {librosa.get_duration(y=y, sr=sr):.2f} seconds")

# Group onsets into playable notes
# Use beats as quantization grid, and assign onsets to lanes
notes = []
lanes = [0, 1, 2]
lane_idx = 0

# Filter onsets - only use strong ones
onset_strength = librosa.onset.onset_strength(y=y, sr=sr)
onset_times = librosa.frames_to_time(librosa.onset.onset_detect(y=y, sr=sr), sr=sr)

# Create notes from the significant onsets
# Skip the first second for intro
filtered_onsets = [t for t in onset_times if t > 1.0 and t < 100]  # Use first 100 seconds

print(f"\nFiltered onsets (1-100s): {len(filtered_onsets)}")
print(f"Creating notes...")
for i, t in enumerate(filtered_onsets):
    lane = lanes[i % 3]
    note_id = str(uuid.uuid4())
    notes.append({
        "id": note_id,
        "time": round(t, 3),
        "lane": lane
    })

if len(filtered_onsets) > 0:
    print(f"First 10 notes:")
    for note in notes[:10]:
        print(f"  {note['time']:.3f}s -> Lane {note['lane']}")
    print(f"Last 10 notes:")
    for note in notes[-10:]:
        print(f"  {note['time']:.3f}s -> Lane {note['lane']}")

# Create the chart
chart = {
    "songName": "Track 3",
    "bpm": int(float(tempo)),
    "offset": 0.0,
    "lanes": 3,
    "notes": notes
}

# Write to JSON
output_path = "/Users/jonny/RhythmTap/RhythmTap/Resources/chart.json"
with open(output_path, 'w') as f:
    json.dump(chart, f, indent=2)

print(f"\nChart generated with {len(notes)} notes")
print(f"Saved to {output_path}")
