import json
import uuid

BPM = 200.0
OFFSET = 7.22
TICKS_PER_BEAT = 480
LANES = 4
SONG_NAME = "Through The Fire and Flames"
ARTIST = "Dragonforce"

def ticks_to_seconds(ticks):
    beats = ticks / TICKS_PER_BEAT
    seconds = beats * (60.0 / BPM)
    return seconds + OFFSET

def convert_chart(input_path, output_path):
    with open(input_path) as f:
        data = json.load(f)
    notes = data["notes"]
    new_notes = []
    for n in notes:
        new_notes.append({
            "id": str(uuid.uuid4()),
            "time": round(ticks_to_seconds(n["time"]), 6),
            "lane": n["lane"],
            "type": "tap"
        })
    new_chart = {
        "songName": SONG_NAME,
        "artist": ARTIST,
        "bpm": BPM,
        "offset": OFFSET,
        "lanes": LANES,
        "notes": new_notes
    }
    with open(output_path, "w") as f:
        json.dump(new_chart, f, indent=2)

for diff in ["easy", "medium", "hard", "extreme"]:
    path = f"Resources/dragonforce_through_the_fire_and_flames_{diff}.json"
    convert_chart(path, path)

print("All Dragonforce charts converted to game format.")
