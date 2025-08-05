#!/bin/bash

echo "🔧 Fixing Firebase Package Dependencies..."
echo "========================================="

PROJECT_DIR="/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS"
PROJECT_FILE="$PROJECT_DIR/UniversalTranslator.xcodeproj"

echo "1. Removing existing package cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/UniversalTranslator-*/SourcePackages
rm -rf "$PROJECT_FILE/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
echo "✅ Package cache cleared"

echo ""
echo "2. Resetting Swift Package Manager state..."
xcodebuild -resolvePackageDependencies -project "$PROJECT_FILE" -scheme UniversalTranslator 2>/dev/null || true
echo "✅ Package resolution initiated"

echo ""
echo "========================================="
echo "📱 Next Steps in Xcode:"
echo ""
echo "1. Open UniversalTranslator.xcodeproj in Xcode"
echo "2. Wait for 'Resolving Package Versions' to complete"
echo "   (You'll see a progress bar at the top of Xcode)"
echo ""
echo "If packages still don't resolve:"
echo "1. File → Packages → Reset Package Caches"
echo "2. File → Packages → Resolve Package Versions"
echo "3. File → Packages → Update to Latest Package Versions"
echo ""
echo "Alternative fix:"
echo "1. Select the project in navigator"
echo "2. Go to Package Dependencies tab"
echo "3. Click the '+' button"
echo "4. Enter: https://github.com/firebase/firebase-ios-sdk"
echo "5. Add these packages:"
echo "   - FirebaseAnalytics"
echo "   - FirebaseAuth"
echo "   - FirebaseFirestore"
echo "   - FirebaseFirestoreSwift"
echo "   - FirebaseStorage"
echo ""
echo "The packages should download and the project will build successfully!"