#!/bin/bash

echo "📱 Launching Universal Translator in iOS Simulator..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Boot the simulator
echo "🚀 Starting iPhone 15 Pro simulator..."
xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || echo "Simulator already booted"

# Open Simulator app
open -a Simulator

# Wait for simulator to be ready
sleep 3

# Build and install the app
echo "🔨 Building and installing app..."
xcodebuild build \
    -project "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj" \
    -scheme "UniversalTranslator" \
    -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=latest" \
    -configuration Debug \
    -derivedDataPath /tmp/UniversalTranslatorBuild \
    -quiet

# Find the app bundle
APP_PATH="/tmp/UniversalTranslatorBuild/Build/Products/Debug-iphonesimulator/UniversalTranslator.app"

if [ -d "$APP_PATH" ]; then
    echo "📲 Installing app to simulator..."
    xcrun simctl install booted "$APP_PATH"
    
    echo "🎯 Launching Universal Translator..."
    xcrun simctl launch booted com.universaltranslator.app
    
    echo ""
    echo "✅ App launched successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 Universal Translator is now running!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Test the following features:"
    echo "1. 🌐 Tap WiFi icon to test API connection"
    echo "2. 🔤 Enter text and translate between languages"
    echo "3. 📋 Copy translated text to clipboard"
    echo "4. 🔄 Swap languages with the arrow button"
    echo "5. 📜 View translation history (clock icon)"
    echo ""
    echo "Check Xcode console for Firebase initialization logs"
else
    echo "❌ Could not find app bundle at: $APP_PATH"
    echo "Please build the project in Xcode first"
    exit 1
fi