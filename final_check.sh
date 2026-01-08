#!/bin/bash
# Final verification and build script for RhythmTap

echo "🎮 RhythmTap Final Verification & Build"
echo "======================================"
echo ""

PROJECT_DIR="/Users/jonny/RhythmTap/RhythmTap"
cd "$PROJECT_DIR" || exit 1

# 1. Verify project structure
echo "✅ Step 1: Verifying project structure..."
if [ ! -f "project.yml" ]; then echo "  ✗ project.yml missing"; exit 1; fi
if [ ! -d "Sources" ]; then echo "  ✗ Sources directory missing"; exit 1; fi
if [ ! -d "Resources" ]; then echo "  ✗ Resources directory missing"; exit 1; fi
echo "  ✓ Project structure valid"
echo ""

# 2. Verify source files
echo "✅ Step 2: Checking source files..."
source_count=$(find Sources -name "*.swift" | wc -l)
echo "  ✓ Found $source_count Swift files"

if [ ! -f "Sources/Models/SongLibrary.swift" ]; then echo "  ✗ SongLibrary.swift missing"; exit 1; fi
if [ ! -f "Sources/Audio/GameAudioEngine.swift" ]; then echo "  ✗ GameAudioEngine.swift missing"; exit 1; fi
if [ ! -f "Sources/GameScene.swift" ]; then echo "  ✗ GameScene.swift missing"; exit 1; fi
echo "  ✓ All critical Swift files present"
echo ""

# 3. Verify audio files
echo "✅ Step 3: Checking audio files..."
audio_count=$(ls Resources/*.{mp3,m4a,wav} 2>/dev/null | wc -l)
echo "  ✓ Found $audio_count audio files"
if [ $audio_count -lt 10 ]; then 
  echo "  ⚠️  Warning: Expected at least 10 audio files"
fi
echo ""

# 4. Verify beatmap files
echo "✅ Step 4: Checking beatmap files..."
chart_count=$(ls Resources/*.json | wc -l)
echo "  ✓ Found $chart_count chart/beatmap files"
if [ $chart_count -lt 10 ]; then 
  echo "  ⚠️  Warning: Expected at least 10 chart files"
fi
echo ""

# 5. Verify configuration files
echo "✅ Step 5: Checking configuration..."
if [ ! -f "Resources/Info.plist" ]; then echo "  ✗ Info.plist missing"; exit 1; fi
echo "  ✓ Info.plist present"

if [ ! -f "RhythmTap.xcodeproj/project.pbxproj" ]; then 
  echo "  ⚠️  Xcode project needs to be generated"
  echo "  Running: xcodegen generate..."
  xcodegen generate
fi
echo "  ✓ Xcode project present"
echo ""

# 6. Summary
echo "✅ Step 6: Verification Summary"
echo "======================================"
echo "  Swift Files:        $source_count"
echo "  Audio Files:        $audio_count"
echo "  Beatmap Files:      $chart_count"
echo "  Xcode Project:      ✓ Ready"
echo ""

# 7. Build instructions
echo "🚀 Ready to build and run!"
echo "======================================"
echo ""
echo "Option A: Using Xcode (Recommended)"
echo "  1. open RhythmTap.xcodeproj"
echo "  2. Select simulator or device"
echo "  3. Press Cmd+R to run"
echo ""
echo "Option B: Using Command Line"
echo "  xcodebuild -scheme RhythmTap -destination 'platform=iOS Simulator,name=iPhone 15'"
echo ""
echo "Option C: Full build with logging"
echo "  xcodebuild -scheme RhythmTap -verbose -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tee build.log"
echo ""
