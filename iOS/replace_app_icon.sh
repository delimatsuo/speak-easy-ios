#!/bin/bash

# Mervyn Talks - App Icon Replacement Script
# This script replaces all app icon assets with the user's custom icon

set -e

SOURCE_ICON="/Users/delimatsuo/Desktop/icon speak easy.png"
ICON_DIR="Assets.xcassets/AppIcon.appiconset"

echo "🎨 Replacing Mervyn Talks app icon with custom icon..."
echo "📁 Source: $SOURCE_ICON"
echo "📁 Target: $ICON_DIR"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "❌ Error: Source icon not found at $SOURCE_ICON"
    exit 1
fi

# Create backup of existing icons
echo "💾 Creating backup of existing icons..."
cp -r "$ICON_DIR" "${ICON_DIR}_backup_$(date +%Y%m%d_%H%M%S)"

# Define all required icon sizes for iOS
declare -a SIZES=(
    "20:AppIcon-20@1x.png"
    "40:AppIcon-20@2x.png"
    "60:AppIcon-20@3x.png"
    "29:AppIcon-29@1x.png"
    "58:AppIcon-29@2x.png"
    "87:AppIcon-29@3x.png"
    "40:AppIcon-40@1x.png"
    "80:AppIcon-40@2x.png"
    "120:AppIcon-40@3x.png"
    "120:AppIcon-60@2x.png"
    "180:AppIcon-60@3x.png"
    "76:AppIcon-76@1x.png"
    "152:AppIcon-76@2x.png"
    "167:AppIcon-83.5@2x.png"
    "1024:AppIcon-1024@1x.png"
)

echo "🔄 Generating icon sizes..."

# Generate all required sizes
for size_info in "${SIZES[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    output_path="$ICON_DIR/$filename"
    
    echo "  📱 Generating ${size}x${size} -> $filename"
    sips -z $size $size "$SOURCE_ICON" --out "$output_path" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "    ✅ Generated: $filename"
    else
        echo "    ❌ Failed: $filename"
    fi
done

echo ""
echo "🎉 App icon replacement complete!"
echo "📊 Generated $(ls -1 $ICON_DIR/*.png | wc -l | tr -d ' ') icon files"
echo ""
echo "Next steps:"
echo "1. Clean and rebuild your Xcode project"
echo "2. Test the new icon in simulator/device"
echo "3. Commit the changes to git"
