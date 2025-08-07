#!/bin/bash

echo "🎤 Building and Launching VoiceBridge..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Build the app
echo "🔨 Building VoiceBridge app..."
xcodebuild build \
    -project "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj" \
    -scheme "UniversalTranslator" \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=latest" \
    -configuration Debug \
    -derivedDataPath /tmp/VoiceTranslatorBuild \
    -quiet

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Boot simulator
    echo "📱 Starting simulator..."
    xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || echo "Simulator already booted"
    
    # Wait for simulator
    sleep 3
    
    # Install app
    echo "📲 Installing VoiceBridge..."
    APP_PATH="/tmp/VoiceTranslatorBuild/Build/Products/Debug-iphonesimulator/UniversalTranslator.app"
    xcrun simctl install booted "$APP_PATH"
    
    # Launch app
    echo "🚀 Launching VoiceBridge..."
    xcrun simctl launch booted com.universaltranslator.app
    
    echo ""
    echo "✅ VoiceBridge is now running!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎤 Voice Translation Features:"
    echo ""
    echo "1. 🎙️  Tap the microphone button to start recording"
    echo "2. 🗣️  Speak in your selected language"
    echo "3. 🛑  Tap stop or wait for auto-stop (60s)"
    echo "4. 🔊  Translation will play automatically"
    echo "5. 🔄  Use replay button to hear again"
    echo "6. 📜  Check history for past translations"
    echo ""
    echo "Note: Grant microphone and speech permissions when prompted"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "❌ Build failed! Check Xcode for errors."
    exit 1
fi