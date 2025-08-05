#!/bin/bash

# Build and Test Script for Universal Translator iOS App

PROJECT_PATH="/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj"
SCHEME="UniversalTranslator"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro,OS=latest"

echo "🔨 Building Universal Translator iOS App..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -project "$PROJECT_PATH" -scheme "$SCHEME" -quiet

# Resolve package dependencies
echo "📦 Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project "$PROJECT_PATH" -scheme "$SCHEME" -quiet

# Build the project
echo "🏗️  Building project..."
xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    -quiet \
    -derivedDataPath ./DerivedData

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Optional: Run the app in simulator
    echo ""
    echo "Would you like to run the app in the simulator? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "📱 Launching app in simulator..."
        xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
        
        # Install and launch the app
        APP_PATH="./DerivedData/Build/Products/Debug-iphonesimulator/UniversalTranslator.app"
        if [ -d "$APP_PATH" ]; then
            xcrun simctl install booted "$APP_PATH"
            xcrun simctl launch booted com.universaltranslator.app
            echo "✅ App launched in simulator!"
        else
            echo "❌ Could not find built app at: $APP_PATH"
        fi
    fi
else
    echo "❌ Build failed!"
    echo "Check the errors above for details."
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Universal Translator Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"