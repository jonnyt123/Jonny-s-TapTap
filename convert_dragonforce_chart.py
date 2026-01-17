import re
import json
import random

# Input and output paths
chart_path = "Resources/Dragonforce - Through The Fire and The Flames/notes.chart"
output_paths = {
    "easy": "Resources/dragonforce_through_the_fire_and_flames_easy.json",
    "medium": "Resources/dragonforce_through_the_fire_and_flames_medium.json",
    "hard": "Resources/dragonforce_through_the_fire_and_flames_hard.json",
    "extreme": "Resources/dragonforce_through_the_fire_and_flames_extreme.json",
}

# Difficulty scaling factors
scales = {
    "easy": 0.25,
    "medium": 0.5,
    "hard": 0.75,
    "extreme": 1.0,
}

# Only use lanes 0-3 for this game
valid_lanes = {"0", "1", "2", "3"}

# Parse the .chart file for [ExpertSingle] notes
with open(chart_path, "r") as f:
    lines = f.readlines()

# Find the [ExpertSingle] section
start = None
end = None
for i, line in enumerate(lines):
    if line.strip() == "[ExpertSingle]":
        start = i
    elif start is not None and line.strip().startswith("[") and not line.strip().startswith("[ExpertSingle]"):
        end = i
        break
if start is None:
    raise Exception("[ExpertSingle] section not found")
if end is None:
    end = len(lines)

note_lines = lines[start:end]

# Extract all notes: N <time> <lane> <duration>
note_pattern = re.compile(r"(\d+) = N (\d) (\d+)")
notes = []
for line in note_lines:
    m = note_pattern.search(line)
    if m and m.group(2) in valid_lanes:
        notes.append({
            "time": int(m.group(1)),
            "lane": int(m.group(2)),
            "duration": int(m.group(3)),
        })

# Sort notes by time
notes.sort(key=lambda n: n["time"])

def scale_notes(notes, scale):
    if scale >= 1.0:
        return notes
    # Uniformly sample notes to reduce density
    count = int(len(notes) * scale)
    return sorted(random.sample(notes, count), key=lambda n: n["time"])

# Write notes for each difficulty
for diff, path in output_paths.items():
    scaled = scale_notes(notes, scales[diff])
    # Convert to game JSON format: {"notes": [{"time":..., "lane":..., "duration":...}, ...]}
    with open(path, "w") as f:
        json.dump({"notes": scaled}, f, indent=2)

print("Done: notes written for all difficulties.")
