#!/bin/bash

echo "🔧 Fixing Assets.xcassets Path Issue..."
echo "======================================"

PROJECT_DIR="/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS"

# Ensure Assets.xcassets is in the right place with proper structure
echo "1. Verifying Assets.xcassets structure..."

# Check if Assets.xcassets exists in both locations
if [ -d "$PROJECT_DIR/Assets.xcassets/AppIcon.appiconset" ]; then
    echo "✅ Found Assets.xcassets in iOS directory"
    
    # Verify Contents.json exists
    if [ -f "$PROJECT_DIR/Assets.xcassets/Contents.json" ] && [ -f "$PROJECT_DIR/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
        echo "✅ Contents.json files are present"
    else
        echo "❌ Missing Contents.json files!"
    fi
    
    # Count icon files
    ICON_COUNT=$(ls -1 "$PROJECT_DIR/Assets.xcassets/AppIcon.appiconset/"*.png 2>/dev/null | wc -l)
    echo "✅ Found $ICON_COUNT icon files"
else
    echo "❌ Assets.xcassets not found or incomplete!"
fi

echo ""
echo "2. Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/UniversalTranslator-*
echo "✅ Cleaned DerivedData"

echo ""
echo "======================================"
echo "📱 Steps to Fix in Xcode:"
echo ""
echo "1. Open UniversalTranslator.xcodeproj"
echo "2. In the file navigator, look for Assets.xcassets"
echo "   - If it has a red name, delete it (right-click → Delete → Remove Reference)"
echo "3. Right-click on the project folder → Add Files to 'UniversalTranslator'"
echo "4. Navigate to: $PROJECT_DIR"
echo "5. Select 'Assets.xcassets'"
echo "6. Make sure:"
echo "   - 'Copy items if needed' is UNCHECKED"
echo "   - 'Create groups' is selected"
echo "   - Your app target is checked"
echo "7. Click 'Add'"
echo ""
echo "8. Clean Build Folder (Shift+Cmd+K)"
echo "9. Build and Run (Cmd+R)"
echo ""
echo "Your Mervyn Talks icon should now appear!"
echo "======================================"