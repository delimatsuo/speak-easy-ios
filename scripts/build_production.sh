#!/bin/bash

# Production Build Script for Universal AI Translator
# Builds and prepares app for App Store submission

set -e

echo "🏗️ Universal AI Translator - Production Build"
echo "════════════════════════════════════════════"

# Configuration
PROJECT_PATH="iOS/UniversalTranslator.xcodeproj"
SCHEME="UniversalTranslator"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/UniversalTranslator.xcarchive"
EXPORT_PATH="./build/export"
EXPORT_OPTIONS="scripts/ExportOptions.plist"

# Environment setup
if [ -f ".env.production" ]; then
    echo "📋 Loading production environment..."
    source .env.production
    export ENVIRONMENT=production
else
    echo "⚠️ No .env.production file found - using defaults"
    export ENVIRONMENT=production
fi

# Verify required environment variables
if [ -z "$TEAM_ID" ]; then
    echo "❌ TEAM_ID not set in environment"
    echo "Please set your Apple Team ID in .env.production"
    exit 1
fi

echo "📋 Build Configuration:"
echo "   Project: $PROJECT_PATH"
echo "   Scheme: $SCHEME"
echo "   Configuration: $CONFIGURATION"
echo "   Team ID: $TEAM_ID"
echo "   Environment: $ENVIRONMENT"
echo ""

# Create build directory
echo "📁 Creating build directory..."
mkdir -p build
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild clean \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION"

# Validate project settings
echo "🔍 Validating project configuration..."
if ! xcodebuild -list -project "$PROJECT_PATH" | grep -q "$SCHEME"; then
    echo "❌ Scheme '$SCHEME' not found in project"
    exit 1
fi

# Create archive
echo "📦 Creating archive..."
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    | tee build/archive.log

# Verify archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive creation failed"
    echo "Check build/archive.log for details"
    exit 1
fi

echo "✅ Archive created successfully"

# Export for App Store
echo "📤 Exporting for App Store..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | tee build/export.log

# Verify export
if [ ! -f "$EXPORT_PATH/UniversalTranslator.ipa" ]; then
    echo "❌ Export failed - IPA not found"
    echo "Check build/export.log for details"
    exit 1
fi

echo "✅ Export completed successfully"

# Show build info
echo ""
echo "📊 Build Summary:"
echo "════════════════"
echo "   Archive: $ARCHIVE_PATH"
echo "   IPA: $EXPORT_PATH/UniversalTranslator.ipa"
echo "   Size: $(du -h "$EXPORT_PATH/UniversalTranslator.ipa" | cut -f1)"
echo "   Timestamp: $(date)"
echo ""

# Security verification
echo "🔍 Security Verification:"
echo "═══════════════════════"

# Check for embedded provisioning profile
if security cms -D -i "$ARCHIVE_PATH/Products/Applications/UniversalTranslator.app/embedded.mobileprovision" &>/dev/null; then
    echo "✅ Embedded provisioning profile found"
    
    # Show profile info
    PROFILE_INFO=$(security cms -D -i "$ARCHIVE_PATH/Products/Applications/UniversalTranslator.app/embedded.mobileprovision")
    TEAM_NAME=$(echo "$PROFILE_INFO" | plutil -extract TeamName raw -)
    BUNDLE_ID=$(echo "$PROFILE_INFO" | plutil -extract Entitlements.application-identifier raw - | cut -d. -f2-)
    
    echo "   Team: $TEAM_NAME"
    echo "   Bundle ID: $BUNDLE_ID"
else
    echo "❌ No embedded provisioning profile found"
fi

# Check code signing
CODESIGN_INFO=$(codesign -dv --verbose=4 "$ARCHIVE_PATH/Products/Applications/UniversalTranslator.app" 2>&1)
if echo "$CODESIGN_INFO" | grep -q "Apple Distribution"; then
    echo "✅ Code signing verified (Apple Distribution)"
else
    echo "⚠️ Code signing verification needs review"
    echo "$CODESIGN_INFO"
fi

echo ""
echo "🎯 Next Steps:"
echo "══════════════"
echo "1. Test the IPA on a physical device"
echo "2. Upload to App Store Connect:"
echo "   xcrun altool --upload-app -f '$EXPORT_PATH/UniversalTranslator.ipa' -u your-apple-id@email.com"
echo "3. Complete metadata in App Store Connect"
echo "4. Submit for review"
echo ""

echo "🚀 Production build completed successfully!"
echo "Ready for App Store submission ✨"
