import json
import uuid

# Settings
BPM = 200.0
OFFSET = 7.22
TICKS_PER_BEAT = 480  # from .chart file
LANES = 4
SONG_NAME = "Through The Fire and Flames"
ARTIST = "Dragonforce"

# Load the original chart
with open("Resources/dragonforce_through_the_fire_and_flames_extreme.json") as f:
    data = json.load(f)

notes = data["notes"]

# Convert ticks to seconds
def ticks_to_seconds(ticks):
    beats = ticks / TICKS_PER_BEAT
    seconds = beats * (60.0 / BPM)
    return seconds + OFFSET

# Convert notes to new format
new_notes = []
for n in notes:
    new_notes.append({
        "id": str(uuid.uuid4()),
        "time": round(ticks_to_seconds(n["time"]), 6),
        "lane": n["lane"],
        "type": "tap",
        # Only add duration if it's a hold (not used here, but for compatibility)
        # "duration": ...
    })

# Build new chart structure
new_chart = {
    "songName": SONG_NAME,
    "artist": ARTIST,
    "bpm": BPM,
    "offset": OFFSET,
    "lanes": LANES,
    "notes": new_notes
}

with open("Resources/dragonforce_through_the_fire_and_flames_extreme.json", "w") as f:
    json.dump(new_chart, f, indent=2)

print("Converted Dragonforce extreme chart to game format.")
