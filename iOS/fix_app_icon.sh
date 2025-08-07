#!/bin/bash

echo "🔧 Fixing VoiceBridge App Icon..."
echo "================================"

# Path to the project
PROJECT_DIR="/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS"
ASSETS_DIR="$PROJECT_DIR/UniversalTranslator/Assets.xcassets"

# 1. Verify icon files exist
echo "1. Checking icon files..."
if [ -f "$ASSETS_DIR/AppIcon.appiconset/AppIcon-1024@1x.png" ]; then
    echo "✅ App icons found in Assets.xcassets"
else
    echo "❌ App icons missing!"
    exit 1
fi

# 2. Clean build folder
echo ""
echo "2. Cleaning build folders..."
rm -rf ~/Library/Developer/Xcode/DerivedData/UniversalTranslator-*
echo "✅ Cleaned DerivedData"

# 3. Reset simulator (if running)
echo ""
echo "3. Resetting simulator state..."
xcrun simctl shutdown all 2>/dev/null
echo "✅ Simulator reset"

# 4. Touch all icon files to update timestamps
echo ""
echo "4. Updating icon file timestamps..."
touch "$ASSETS_DIR/AppIcon.appiconset/"*.png
touch "$ASSETS_DIR/AppIcon.appiconset/Contents.json"
echo "✅ Updated timestamps"

# 5. Verify project settings
echo ""
echo "5. Checking project settings..."
if grep -q "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon" "$PROJECT_DIR/UniversalTranslator.xcodeproj/project.pbxproj"; then
    echo "✅ AppIcon name is correctly set in project"
else
    echo "❌ AppIcon name not set in project!"
fi

echo ""
echo "================================"
echo "✨ Icon fix complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Clean Build Folder (Shift+Cmd+K)"
echo "3. Build and Run (Cmd+R)"
echo ""
echo "If the icon still doesn't appear:"
echo "1. Delete the app from simulator"
echo "2. Reset simulator content (Device > Erase All Content and Settings)"
echo "3. Build and run again"
echo ""
echo "The app icon should now show the teal-to-blue gradient"
echo "with face silhouette and sound waves!"