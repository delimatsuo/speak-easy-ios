#!/bin/bash

# VoiceBridge - App Store Screenshot Generation Script
# This script generates screenshots for all required device sizes

set -e

echo "🎯 Generating App Store Screenshots for VoiceBridge..."

# Create screenshots directory
mkdir -p Screenshots/iPhone_6_9
mkdir -p Screenshots/iPhone_6_7  
mkdir -p Screenshots/iPhone_6_5
mkdir -p Screenshots/iPhone_5_5
mkdir -p Screenshots/iPad_Pro_12_9
mkdir -p Screenshots/iPad_Pro_11

# Device configurations for screenshots
DEVICE_KEYS=("iPhone_6_9" "iPhone_6_7" "iPhone_6_5" "iPhone_5_5" "iPad_Pro_12_9" "iPad_Pro_11")
DEVICE_NAMES=("iPhone 16 Pro Max" "iPhone 16 Plus" "iPhone 15 Pro" "iPhone 8 Plus" "iPad Pro 12.9-inch (6th generation)" "iPad Pro 11-inch (4th generation)")

# Screenshot scenarios
SCENARIOS=(
    "home_screen"
    "recording_active"
    "translation_results"
    "language_selection"
    "settings_screen"
    "conversation_history"
)

echo "📱 Building app for screenshot generation..."
xcodebuild -project UniversalTranslator.xcodeproj -scheme UniversalTranslator -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=latest' build

echo "🖼️ Generating screenshots for each device..."

for i in "${!DEVICE_KEYS[@]}"; do
    device_key="${DEVICE_KEYS[$i]}"
    device_name="${DEVICE_NAMES[$i]}"
    echo "📱 Processing $device_name..."
    
    # Boot simulator
    xcrun simctl boot "$device_name" 2>/dev/null || true
    sleep 3
    
    # Install app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "UniversalTranslator.app" -path "*/Release-iphonesimulator/*" | head -1)
    if [ -n "$APP_PATH" ]; then
        xcrun simctl install "$device_name" "$APP_PATH"
        
        # Launch app
        xcrun simctl launch "$device_name" com.universaltranslator.app
        sleep 5
        
        # Take screenshots
        for i in {1..6}; do
            screenshot_name="Screenshots/${device_key}/screenshot_${i}.png"
            xcrun simctl io "$device_name" screenshot "$screenshot_name"
            echo "✅ Generated: $screenshot_name"
            sleep 2
        done
        
        # Terminate app
        xcrun simctl terminate "$device_name" com.universaltranslator.app
    else
        echo "❌ Could not find app build for $device_name"
    fi
    
    # Shutdown simulator
    xcrun simctl shutdown "$device_name" 2>/dev/null || true
done

echo "🎉 Screenshot generation complete!"
echo "📁 Screenshots saved in: $(pwd)/Screenshots/"
echo ""
echo "Next steps:"
echo "1. Review screenshots in Screenshots/ directory"
echo "2. Edit screenshots to show different app states"
echo "3. Upload to App Store Connect"
