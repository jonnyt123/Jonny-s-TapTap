#!/bin/bash
# RhythmTap - Quick Command Reference
# Copy and paste commands below to manage your project

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 BUILD & RUN
# ═══════════════════════════════════════════════════════════════════════════

# Open in Xcode (recommended)
open /Users/jonny/RhythmTap/RhythmTap/RhythmTap.xcodeproj

# Build via command line
cd /Users/jonny/RhythmTap/RhythmTap || exit
xcodebuild -scheme RhythmTap -destination 'platform=iOS Simulator,name=iPhone 15'

# Build with verbose output (debugging)
xcodebuild -scheme RhythmTap -verbose -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tee build.log

# ═══════════════════════════════════════════════════════════════════════════
# ✅ VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════

# Run final verification script
bash /Users/jonny/RhythmTap/RhythmTap/final_check.sh

# Verify all files
python3 /Users/jonny/RhythmTap/RhythmTap/verify_files.py

# Count files
ls -1 /Users/jonny/RhythmTap/RhythmTap/Resources/*.mp3 | wc -l   # Audio count
ls -1 /Users/jonny/RhythmTap/RhythmTap/Resources/*.json | wc -l  # Chart count

# ═══════════════════════════════════════════════════════════════════════════
# 🎵 MANAGE SONGS
# ═══════════════════════════════════════════════════════════════════════════

# Prepare and add new songs
cd /Users/jonny/RhythmTap/RhythmTap || exit
python3 prepare_songs.py

# Regenerate Xcode project after changes
xcodegen generate

# List all songs in Resources
find /Users/jonny/RhythmTap/RhythmTap/Resources -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.wav" \) -print0 | xargs -0 -n1 basename | sort

# List all beatmaps
find /Users/jonny/RhythmTap/RhythmTap/Resources -type f -name "*.json" ! -name "*legacy*" -print0 | xargs -0 -n1 basename | sort

# ═══════════════════════════════════════════════════════════════════════════
# 📝 EDIT & CUSTOMIZE
# ═══════════════════════════════════════════════════════════════════════════

# Open source files in editor
code /Users/jonny/RhythmTap/RhythmTap/Sources/GameScene.swift          # Game parameters
code /Users/jonny/RhythmTap/RhythmTap/Sources/Models/SongLibrary.swift # Song metadata
code /Users/jonny/RhythmTap/RhythmTap/Sources/Audio/GameAudioEngine.swift # Audio setup

# Open project directory
open /Users/jonny/RhythmTap/RhythmTap/

# ═══════════════════════════════════════════════════════════════════════════
# 🧹 CLEANUP & MAINTENANCE
# ═══════════════════════════════════════════════════════════════════════════

# Remove build artifacts
rm -rf /Users/jonny/RhythmTap/RhythmTap/build
rm -rf /Users/jonny/RhythmTap/RhythmTap/DerivedData

# Clean Xcode build folder
cd /Users/jonny/RhythmTap/RhythmTap || exit
xcodebuild clean

# Regenerate Xcode project from scratch
xcodegen generate --force

# ═══════════════════════════════════════════════════════════════════════════
# 📊 PROJECT INFO
# ═══════════════════════════════════════════════════════════════════════════

# Show project structure
tree -L 2 /Users/jonny/RhythmTap/RhythmTap/

# List all Swift files
find /Users/jonny/RhythmTap/RhythmTap/Sources -name "*.swift" | sort

# Count lines of code
find /Users/jonny/RhythmTap/RhythmTap/Sources -name "*.swift" -print0 | xargs -0 wc -l | tail -1

# Disk usage
du -sh /Users/jonny/RhythmTap/RhythmTap/

# ═══════════════════════════════════════════════════════════════════════════
# 🔍 DEBUGGING
# ═══════════════════════════════════════════════════════════════════════════

# Check audio file validity
file /Users/jonny/RhythmTap/RhythmTap/Resources/*.mp3

# Validate JSON beatmaps
python3 -m json.tool /Users/jonny/RhythmTap/RhythmTap/Resources/*.json

# View build log
tail -100 build.log

# Check Swift syntax
swiftc -parse /Users/jonny/RhythmTap/RhythmTap/Sources/GameScene.swift

# ═══════════════════════════════════════════════════════════════════════════
# 📱 DEVICE TESTING
# ═══════════════════════════════════════════════════════════════════════════

# List available simulators
xcrun simctl list devices available

# Build for physical device
xcodebuild -scheme RhythmTap -destination 'platform=iOS,name=My Device' archive

# ═══════════════════════════════════════════════════════════════════════════
# 📚 DOCUMENTATION
# ═══════════════════════════════════════════════════════════════════════════

# View main README
cat /Users/jonny/RhythmTap/RhythmTap/README.md

# View quick start guide
cat /Users/jonny/RhythmTap/RhythmTap/QUICK_START.md

# View completion summary
cat /Users/jonny/RhythmTap/RhythmTap/COMPLETION_SUMMARY.md

# View setup guide
cat /Users/jonny/RhythmTap/RhythmTap/SETUP_COMPLETE.md

# ═══════════════════════════════════════════════════════════════════════════
# 🎮 GAME PARAMETERS (Edit in GameScene.swift)
# ═══════════════════════════════════════════════════════════════════════════

# Current values:
# hitWindow = 0.16        (Timing window in seconds)
# noteSpeed = 350         (Pixels per second)
# spawnLeadTime = 2.8     (Preview time in seconds)
# startDelay = 0.35       (Audio sync delay)

# To make game easier:
#   Increase hitWindow to 0.20
#   Decrease noteSpeed to 280

# To make game harder:
#   Decrease hitWindow to 0.12
#   Increase noteSpeed to 400

# ═══════════════════════════════════════════════════════════════════════════
# 🎨 QUICK CUSTOMIZATION
# ═══════════════════════════════════════════════════════════════════════════

# Find and replace lane colors in GameScene.swift
sed -i '' 's/1.0, green: 0.3, blue: 0.3/0.8, green: 0.2, blue: 0.8/g' Sources/GameScene.swift

# Change all song colors to purple theme
sed -i '' 's/accent: \./accent: .purple/g' Sources/Models/SongLibrary.swift

# ═══════════════════════════════════════════════════════════════════════════
# 💾 BACKUP & VERSION CONTROL
# ═══════════════════════════════════════════════════════════════════════════

# Create backup
cp -r /Users/jonny/RhythmTap/RhythmTap "/Users/jonny/RhythmTap/RhythmTap_backup_$(date +%Y%m%d)"

# List backups
ls -d /Users/jonny/RhythmTap/RhythmTap_backup_* 2>/dev/null

# ═══════════════════════════════════════════════════════════════════════════
# 📞 QUICK LINKS
# ═══════════════════════════════════════════════════════════════════════════

# Project Directory
cd /Users/jonny/RhythmTap/RhythmTap || exit

# Open Xcode
open RhythmTap.xcodeproj

# View songs
ls Resources/*.{mp3,m4a,wav}

# View beatmaps
ls Resources/*.json

# Edit main game file
code Sources/GameScene.swift

# Edit song library
code Sources/Models/SongLibrary.swift

# Edit audio engine
code Sources/Audio/GameAudioEngine.swift

# ═══════════════════════════════════════════════════════════════════════════

# NOTE: Copy and paste individual commands into terminal as needed
# For multiple commands, run: bash this_file.sh
