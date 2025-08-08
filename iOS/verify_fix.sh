#!/bin/bash

echo "🔧 Verifying API Key Configuration Fix"
echo "======================================="

# 1. Check if plist file exists
if [ -f "api_keys.plist" ]; then
    echo "✅ api_keys.plist exists in project directory"
else
    echo "❌ api_keys.plist missing from project directory"
    exit 1
fi

# 2. Verify plist content
echo ""
echo "📄 Checking plist content:"
if grep -q "GoogleTranslateAPIKey" api_keys.plist; then
    echo "✅ GoogleTranslateAPIKey found in plist"
else
    echo "❌ GoogleTranslateAPIKey missing from plist"
fi

if grep -Eqs "AIza[0-9A-Za-z_-]{35}" api_keys.plist; then
    echo "❌ Found hardcoded API key value in plist. Replace with placeholder."
    exit 1
else
    echo "✅ No hardcoded API keys present in plist"
fi

# 3. Check Xcode project references
echo ""
echo "🔨 Checking Xcode project integration:"
if grep -q "api_keys.plist" UniversalTranslator.xcodeproj/project.pbxproj; then
    echo "✅ api_keys.plist referenced in Xcode project"
    
    # Count references
    refs=$(grep -c "api_keys.plist" UniversalTranslator.xcodeproj/project.pbxproj)
    echo "   Found $refs references in project file"
else
    echo "❌ api_keys.plist NOT referenced in Xcode project"
fi

# 4. Check if it's in Resources build phase
if grep -q "api_keys.plist in Resources" UniversalTranslator.xcodeproj/project.pbxproj; then
    echo "✅ api_keys.plist included in Resources build phase"
else
    echo "❌ api_keys.plist NOT in Resources build phase"
fi

echo ""
echo "🧪 Next steps to complete verification:"
echo "1. Clean Build Folder: xcodebuild clean -project UniversalTranslator.xcodeproj"
echo "2. Build project: xcodebuild build -project UniversalTranslator.xcodeproj -scheme UniversalTranslator"
echo "3. Run app in simulator and check console logs"
echo "4. Verify APIKeyManager.shared.isAPIKeyConfigured() only after securely injecting key at runtime"

echo ""
echo "🎯 Expected behavior after fix:"
echo "- No more '❌ API key not found' errors"
echo "- App should securely load API key from Keychain (not from committed plist)"
echo "- Translation functionality should work"