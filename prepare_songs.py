#!/usr/bin/env python3
"""
Prepare songs for RhythmTap:
1. Copy audio files to Resources
2. Generate beatmaps based on BPM
3. Create updated SongLibrary.swift
"""

import json
import shutil
import uuid
from pathlib import Path

MUSIC_LIBRARY = Path.home() / "Music"
RESOURCES_DIR = Path("/Users/jonny/RhythmTap/RhythmTap/Resources")

# Define songs to add (with source paths and metadata)
SONGS_TO_ADD = [
    {
        "title": "Hallelujah",
        "artist": "Jonny Thompson",
        "source": "Music/Media.localized/Music/Unknown Artist/Unknown Album/Choir_2025-12-09_19-05-01_Combined.wav",
        "output_name": "hallelujah",
        "extension": "wav",
        "bpm": 110,
        "lanes": 3,
        "colors": ["0.86|0.36|1.0", "0.18|0.31|0.82"],
        "accent": "cyan"
    },
    {
        "title": "Crazy Train",
        "artist": "Ozzy Osbourne",
        "source": "existing",  # Already exists
        "output_name": "crazy_train",
        "extension": "mp3",
        "bpm": 138,
        "lanes": 4,
        "colors": ["0.85|0.24|0.21", "0.08|0.08|0.15"],
        "accent": "orange"
    },
    {
        "title": "I Will Not Bow",
        "artist": "Breaking Benjamin",
        "source": "existing",  # Already exists
        "output_name": "i_will_not_bow",
        "extension": "mp3",
        "bpm": 92,
        "lanes": 4,
        "colors": ["0.10|0.14|0.20", "0.45|0.05|0.08"],
        "accent": "red"
    },
    {
        "title": "Day 'N' Nite",
        "artist": "Kid Cudi",
        "source": "existing",  # Already exists
        "output_name": "day_n_nite",
        "extension": "mp3",
        "bpm": 139.67,
        "lanes": 4,
        "colors": ["0.10|0.22|0.36", "0.00|0.50|0.55"],
        "accent": "mint"
    },
    {
        "title": "See You",
        "artist": "blink-182",
        "source": "Music/Media.localized/Music/Unknown Artist/Unknown Album/blink-182 - SEE YOU (Official Audio).mp3",
        "output_name": "blink182_see_you",
        "extension": "mp3",
        "bpm": 100,
        "lanes": 3,
        "colors": ["0.8|0.2|0.8", "0.0|0.8|0.8"],
        "accent": "yellow"
    },
    {
        "title": "Chainsaw",
        "artist": "Madchild ft. Slaine",
        "source": "Music/Media.localized/Music/Madchild/Lawn Mower Man/04 Chainsaw (feat. Slaine).mp3",
        "output_name": "madchild_chainsaw",
        "extension": "mp3",
        "bpm": 95,
        "lanes": 3,
        "colors": ["0.7|0.0|0.0", "0.0|0.7|0.7"],
        "accent": "red"
    },
    {
        "title": "High Enough",
        "artist": "Hippie Sabotage",
        "source": "Music/Media.localized/Music/Hippie Sabotage/Options/03 High Enough.m4a",
        "output_name": "hippie_sabotage_high",
        "extension": "m4a",
        "bpm": 110,
        "lanes": 3,
        "colors": ["1.0|0.5|0.0", "0.0|0.5|1.0"],
        "accent": "purple"
    },
    {
        "title": "Don't Let Me Go",
        "artist": "MGk",
        "source": "Music/Media.localized/Music/Khawsy/Unknown Album/MGk - Don_t Let Me Go (Instrumental).mp3",
        "output_name": "mgk_dont_let_me_go",
        "extension": "mp3",
        "bpm": 120,
        "lanes": 4,
        "colors": ["0.2|0.2|0.8", "0.8|0.2|0.2"],
        "accent": "cyan"
    },
    {
        "title": "On Fonem Grave",
        "artist": "Bizzy Banks",
        "source": "4K YouTube to MP3/Bizzy Banks -  ON FONEM GRAVE  [ OFFICIAL VIDEO ].mp3",
        "output_name": "bizzy_banks_fonem",
        "extension": "mp3",
        "bpm": 85,
        "lanes": 3,
        "colors": ["0.9|0.7|0.0", "0.1|0.1|0.1"],
        "accent": "orange"
    },
    {
        "title": "Remix Revision",
        "artist": "Original",
        "source": "GarageBand/Project.band/Media/Audio Files/revision-mixdown-final-video.wav",
        "output_name": "remix_revision",
        "extension": "wav",
        "bpm": 115,
        "lanes": 3,
        "colors": ["0.5|0.5|0.5", "0.0|1.0|1.0"],
        "accent": "green"
    }
]

def copy_audio_files():
    """Copy audio files from Music library to Resources"""
    print("📁 Copying audio files...")
    RESOURCES_DIR.mkdir(exist_ok=True)
    
    for song in SONGS_TO_ADD:
        if song["source"] == "existing":
            print(f"  ✓ {song['title']} (already exists)")
            continue
        
        source_path = MUSIC_LIBRARY / song["source"]
        output_path = RESOURCES_DIR / f"{song['output_name']}.{song['extension']}"
        
        if source_path.exists():
            shutil.copy2(source_path, output_path)
            print(f"  ✓ {song['title']}")
        else:
            print(f"  ✗ {song['title']} - Source not found: {source_path}")

def generate_beatmap(song: dict, duration: float = 180) -> dict:
    """Generate a basic beatmap for a song based on BPM"""
    bpm = song["bpm"]
    beat_duration = 60.0 / bpm  # Duration of one beat
    
    notes = []
    
    # Generate notes at regular intervals (every half beat)
    current_time = 1.0
    note_interval = beat_duration / 2
    
    while current_time < duration:
        lane = int((current_time / beat_duration) % song["lanes"])
        notes.append({
            "id": str(uuid.uuid4()),
            "time": round(current_time, 2),
            "lane": lane
        })
        current_time += note_interval
    
    return {
        "songName": song["title"],
        "artist": song["artist"],
        "bpm": song["bpm"],
        "offset": 0.0,
        "lanes": song["lanes"],
        "notes": notes[:250]  # Limit to 250 notes for reasonable gameplay
    }

def create_beatmaps():
    """Generate beatmap JSON files for all songs"""
    print("\n🎵 Generating beatmaps...")
    
    for song in SONGS_TO_ADD:
        beatmap = generate_beatmap(song, duration=180)
        output_file = RESOURCES_DIR / f"{song['output_name']}.json"
        
        with open(output_file, "w") as f:
            json.dump(beatmap, f, indent=2)
        
        print(f"  ✓ {song['title']} - {len(beatmap['notes'])} notes")

def generate_song_library():
    """Generate updated SongLibrary.swift with all songs"""
    print("\n📝 Generating SongLibrary.swift...")
    
    # Parse colors
    color_definitions = []
    for song in SONGS_TO_ADD:
        colors = song["colors"]
        color_tuples = [
            f"Color(red: {c.split('|')[0]}, green: {c.split('|')[1]}, blue: {c.split('|')[2]})"
            for c in colors
        ]
        color_definitions.append({
            "song": song,
            "colors": color_tuples
        })
    
    # Generate Swift code
    swift_code = """import SwiftUI

struct SongMetadata: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let audioName: String
    let audioExtension: String
    let chartName: String
    let lanes: Int
    let bpm: Double
    let primaryColors: [Color]
    let accent: Color
}

extension SongMetadata {
    static let library: [SongMetadata] = [
"""
    
    for cd in color_definitions:
        song = cd["song"]
        colors = cd["colors"]
        accent_color = song["accent"]
        
        swift_code += f"""        SongMetadata(
            id: "{song['output_name']}",
            title: "{song['title']}",
            artist: "{song['artist']}",
            audioName: "{song['output_name']}",
            audioExtension: "{song['extension']}",
            chartName: "{song['output_name']}",
            lanes: {song['lanes']},
            bpm: {song['bpm']},
            primaryColors: [
                {colors[0]},
                {colors[1] if len(colors) > 1 else colors[0]}
            ],
            accent: .{accent_color}
        ),
"""
    
    swift_code += """    ]
    
    static let `default`: SongMetadata = library.first ?? SongMetadata(
        id: "fallback",
        title: "Unknown",
        artist: "",
        audioName: "track",
        audioExtension: "wav",
        chartName: "chart",
        lanes: 3,
        bpm: 120,
        primaryColors: [.purple, .blue],
        accent: .cyan
    )
}
"""
    
    output_file = Path("/Users/jonny/RhythmTap/RhythmTap/Sources/Models/SongLibrary.swift")
    with open(output_file, "w") as f:
        f.write(swift_code)
    
    print(f"  ✓ Created SongLibrary.swift with {len(SONGS_TO_ADD)} songs")

if __name__ == "__main__":
    print("🎮 RhythmTap Song Preparation\n")
    copy_audio_files()
    create_beatmaps()
    generate_song_library()
    print("\n✅ All done! Ready to build the Xcode project.")
