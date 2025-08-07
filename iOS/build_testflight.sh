#!/bin/bash

echo "📱 Building Mervyn Talks for TestFlight"
echo "====================================="
echo ""

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf ../build
mkdir -p ../build

# Build the app
echo "🔨 Building Release configuration..."
xcodebuild -project UniversalTranslator.xcodeproj \
  -scheme UniversalTranslator \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath ../build/DerivedData \
  -allowProvisioningUpdates \
  clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please check Xcode for errors."
    echo ""
    echo "Common fixes:"
    echo "1. Open Xcode and select your Development Team"
    echo "2. Ensure automatic signing is enabled"
    echo "3. Check that all Swift packages are resolved"
    exit 1
fi

# Create archive
echo "📦 Creating archive..."
xcodebuild -project UniversalTranslator.xcodeproj \
  -scheme UniversalTranslator \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath ../build/DerivedData \
  -archivePath ../build/SpeakEasy.xcarchive \
  -allowProvisioningUpdates \
  archive

if [ $? -ne 0 ]; then
    echo "❌ Archive failed."
    exit 1
fi

# Export for App Store
echo "📤 Exporting for App Store..."
xcodebuild -exportArchive \
  -archivePath ../build/SpeakEasy.xcarchive \
  -exportPath ../build/Export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    echo "⚠️  Export failed. Creating ExportOptions.plist..."
    
    cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
    
    echo "Please update ExportOptions.plist with your Team ID and try again."
    exit 1
fi

echo ""
echo "✅ Build complete!"
echo ""
echo "📍 Archive location: ../build/SpeakEasy.xcarchive"
echo "📍 IPA location: ../build/Export/"
echo ""
echo "Next steps:"
echo "1. Open Xcode Organizer (Window > Organizer)"
echo "2. Select the SpeakEasy archive"
echo "3. Click 'Distribute App'"
echo "4. Choose 'App Store Connect'"
echo "5. Upload to TestFlight"
echo ""
echo "Or use Transporter app to upload the IPA directly."