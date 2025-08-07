#!/bin/bash

# Script to fix dSYM upload issues for Firebase frameworks
# Run this before archiving in Xcode

echo "🔧 Fixing dSYM upload configuration for App Store submission..."

# Find the project file
PROJECT_FILE="UniversalTranslator.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "📝 Updating build settings for dSYM generation..."

# Create a temporary xcconfig file with the necessary settings
cat > dsym_fix.xcconfig << 'EOF'
// Ensure dSYMs are generated for all frameworks
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
DWARF_DSYM_FOLDER_PATH = $(CONFIGURATION_BUILD_DIR)
DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT = YES
DEPLOYMENT_POSTPROCESSING = YES
STRIP_INSTALLED_PRODUCT = YES
SEPARATE_STRIP = YES
STRIP_STYLE = non-global

// Firebase specific settings
GCC_GENERATE_DEBUGGING_SYMBOLS = YES
COPY_PHASE_STRIP = NO
ENABLE_BITCODE = NO

// Ensure symbols are embedded
CLANG_ENABLE_MODULES = YES
CLANG_ENABLE_OBJC_ARC = YES
EOF

echo "✅ Created dSYM configuration file"

echo ""
echo "📋 INSTRUCTIONS TO FIX dSYM ISSUES:"
echo "=================================="
echo ""
echo "1. Open Xcode and select your project"
echo ""
echo "2. Select the main app target"
echo ""
echo "3. Go to Build Settings tab"
echo ""
echo "4. Search for 'Debug Information Format'"
echo "   - Set to: 'DWARF with dSYM File' for Release configuration"
echo ""
echo "5. Search for 'Generate Debug Symbols'"
echo "   - Set to: YES"
echo ""
echo "6. Search for 'Enable Bitcode'"
echo "   - Set to: NO (Firebase doesn't support bitcode)"
echo ""
echo "7. Clean Build Folder (Shift+Cmd+K)"
echo ""
echo "8. Archive again (Product → Archive)"
echo ""
echo "ALTERNATIVE: Use Firebase Crashlytics dSYM upload script:"
echo "============================================"
echo ""
echo "If symbols still fail to upload, you can manually upload them after archiving:"
echo ""
echo "1. Find your archive in Xcode Organizer"
echo "2. Right-click → Show in Finder"
echo "3. Right-click the .xcarchive → Show Package Contents"
echo "4. Navigate to dSYMs folder"
echo "5. Run: find . -name '*.dSYM' | xargs -I {} dwarfdump -u {}"
echo "   This will show you which dSYMs are present"
echo ""
echo "For Firebase frameworks specifically, you may need to:"
echo "- Update to the latest Firebase SDK version"
echo "- Use Swift Package Manager instead of CocoaPods"
echo "- Or disable symbol upload for third-party frameworks"
echo ""

# Create a build script to ensure dSYMs are generated
cat > ensure_dsyms.sh << 'EOF'
#!/bin/bash
# Add this as a Build Phase script in Xcode

# Ensure all frameworks have dSYMs
echo "Checking for dSYMs..."

DSYM_DIR="${DWARF_DSYM_FOLDER_PATH}"
if [ -d "$DSYM_DIR" ]; then
    echo "dSYM directory found at: $DSYM_DIR"
    find "$DSYM_DIR" -name "*.dSYM" -print
else
    echo "Warning: dSYM directory not found"
fi
EOF

chmod +x ensure_dsyms.sh

echo "✅ Created ensure_dsyms.sh build script"
echo ""
echo "Optional: Add ensure_dsyms.sh as a Build Phase:"
echo "1. Select your target in Xcode"
echo "2. Go to Build Phases"
echo "3. Click + → New Run Script Phase"
echo "4. Paste: ${PWD}/ensure_dsyms.sh"
echo ""
echo "🎯 The main issue is that third-party Firebase frameworks"
echo "   don't include dSYMs. This is usually OK and won't"
echo "   prevent App Store submission. The warnings can be ignored."
echo ""
echo "If you want to suppress these warnings entirely:"
echo "1. In Xcode Organizer, when uploading"
echo "2. Uncheck 'Upload your app's symbols'"
echo "3. Or uncheck 'Include bitcode'"