#!/usr/bin/env python3
import librosa
import numpy as np
import json

# Load the audio file
audio_path = "/Users/jonny/RhythmTap/RhythmTap/Sources/Audio/track 3.wav"
y, sr = librosa.load(audio_path, sr=None)

# Detect beats using the librosa beat tracking
tempo, beats = librosa.beat.beat_track(y=y, sr=sr)

# Convert frame indices to time
beat_times = librosa.frames_to_time(beats, sr=sr)

print(f"Detected Tempo: {float(tempo):.2f} BPM")
print(f"Number of beats detected: {len(beat_times)}")
print(f"Audio duration: {librosa.get_duration(y=y, sr=sr):.2f} seconds")

# Also detect onsets (transients/note attacks)
onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units='time')
print(f"Number of onsets detected: {len(onset_frames)}")

# Print first 20 beat times
print("\nFirst 20 beat times (seconds):")
for i, t in enumerate(beat_times[:20]):
    print(f"  {i+1}: {t:.3f}s")

print("\nFirst 20 onset times (seconds):")
for i, t in enumerate(onset_frames[:20]):
    print(f"  {i+1}: {t:.3f}s")
