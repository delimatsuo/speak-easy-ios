#!/bin/bash

# Universal Translator App - Production Deployment Script
# Version 3.0.0 - Enterprise Grade Release

set -e

echo "🚀 Universal Translator App - Production Deployment"
echo "=================================================="
echo "Version: 3.0.0 (Enterprise Edition)"
echo "Build: 1"
echo ""

# Configuration
PROJECT_DIR="/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp"
XCODE_PROJECT="$PROJECT_DIR/iOS/UniversalTranslator.xcodeproj"
SCHEME="UniversalTranslator"
ARCHIVE_PATH="$PROJECT_DIR/build/UniversalTranslator.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
EXPORT_OPTIONS_PLIST="$PROJECT_DIR/scripts/ExportOptions.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean previous builds
echo -e "${YELLOW}📦 Step 1: Cleaning previous builds...${NC}"
rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/build"

# Step 2: Update build number
echo -e "${YELLOW}📝 Step 2: Updating build configuration...${NC}"
BUILD_NUMBER=$(date +%Y%m%d%H%M)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PROJECT_DIR/iOS/Resources/Configuration/Info.plist"
echo "Build number updated to: $BUILD_NUMBER"

# Step 3: Clean Xcode build
echo -e "${YELLOW}🧹 Step 3: Cleaning Xcode build...${NC}"
cd "$PROJECT_DIR/iOS"
xcodebuild clean \
  -project "UniversalTranslator.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release

# Step 4: Archive the app
echo -e "${YELLOW}📱 Step 4: Archiving app for App Store...${NC}"
xcodebuild archive \
  -project "UniversalTranslator.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Step 5: Create export options plist
echo -e "${YELLOW}📋 Step 5: Creating export options...${NC}"
cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.universaltranslator.app</key>
        <string>Automatic</string>
        <key>com.universaltranslator.app.watchkitapp</key>
        <string>Automatic</string>
        <key>com.universaltranslator.app.watchkitapp.watchkitextension</key>
        <string>Automatic</string>
    </dict>
</dict>
</plist>
EOF

# Step 6: Export the archive
echo -e "${YELLOW}📤 Step 6: Exporting archive for App Store...${NC}"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates

# Step 7: Validate the app
echo -e "${YELLOW}✅ Step 7: Validating app for App Store...${NC}"
xcrun altool --validate-app \
  -f "$EXPORT_PATH/UniversalTranslator.ipa" \
  -t ios \
  --apiKey "YOUR_API_KEY" \
  --apiIssuer "YOUR_ISSUER_ID" \
  --verbose

# Step 8: Upload to TestFlight
echo -e "${YELLOW}🚀 Step 8: Uploading to TestFlight...${NC}"
echo -e "${YELLOW}To upload to TestFlight, run:${NC}"
echo "xcrun altool --upload-app -f '$EXPORT_PATH/UniversalTranslator.ipa' -t ios --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID"

echo ""
echo -e "${GREEN}✅ Production build completed successfully!${NC}"
echo ""
echo "📱 Archive location: $ARCHIVE_PATH"
echo "📦 IPA location: $EXPORT_PATH/UniversalTranslator.ipa"
echo ""
echo "Next steps:"
echo "1. Replace YOUR_TEAM_ID with your actual Apple Developer Team ID"
echo "2. Configure App Store Connect API keys"
echo "3. Run the upload command to submit to TestFlight"
echo "4. Submit for App Store review once testing is complete"
echo ""
echo "🎉 Version 3.0.0 - Enterprise Edition Ready for Deployment!"