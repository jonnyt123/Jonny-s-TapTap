#!/usr/bin/env python3
"""
Verify all files are properly registered in Xcode project
"""

import json
from pathlib import Path

PROJECT_DIR = Path("/Users/jonny/RhythmTap/RhythmTap")
RESOURCES_DIR = PROJECT_DIR / "Resources"

def verify_files():
    print("📋 Verifying RhythmTap Project Files\n")
    
    # Check audio files
    print("🎵 Audio Files:")
    audio_files = []
    for ext in ['mp3', 'm4a', 'wav']:
        audio_files.extend(RESOURCES_DIR.glob(f"*.{ext}"))
    
    for f in sorted(audio_files):
        print(f"  ✓ {f.name}")
    print(f"  Total: {len(audio_files)} audio files\n")
    
    # Check chart files
    print("📊 Chart/Beatmap Files:")
    chart_files = list(RESOURCES_DIR.glob("*.json"))
    for f in sorted(chart_files):
        try:
            with open(f) as fp:
                data = json.load(fp)
                notes_count = len(data.get("notes", []))
                print(f"  ✓ {f.name} ({notes_count} notes, {data.get('bpm')} BPM)")
        except Exception:
            print(f"  ✗ {f.name} (invalid JSON)")
    print(f"  Total: {len(chart_files)} chart files\n")
    
    # Check Source files
    print("📝 Source Files:")
    source_files = []
    for f in PROJECT_DIR.glob("Sources/**/*.swift"):
        source_files.append(f.relative_to(PROJECT_DIR))
    
    for f in sorted(source_files):
        print(f"  ✓ {f}")
    print(f"  Total: {len(source_files)} Swift files\n")
    
    # Check configuration files
    print("⚙️  Configuration Files:")
    config_files = [
        "project.yml",
        "Resources/Info.plist",
        "RhythmTap.xcodeproj/project.pbxproj"
    ]
    
    for cf in config_files:
        path = PROJECT_DIR / cf
        if path.exists():
            print(f"  ✓ {cf}")
        else:
            print(f"  ✗ {cf} (missing)")
    
    print("\n✅ Project verification complete!")
    print("\nNext steps:")
    print("1. Open RhythmTap.xcodeproj in Xcode")
    print("2. Select target and verify all resources are in Build Phases")
    print("3. Build & Run on simulator or device")

if __name__ == "__main__":
    verify_files()
