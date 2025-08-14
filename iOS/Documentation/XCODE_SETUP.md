# Xcode Setup Instructions for Universal Translator

## Adding GoogleService-Info.plist to Xcode

### Step 1: Open Your Xcode Project
1. Open Xcode
2. Open your Universal Translator project (or create a new one with Bundle ID: `com.universaltranslator.app`)

### Step 2: Add GoogleService-Info.plist
1. In Xcode, right-click on your project folder in the navigator
2. Select "Add Files to 'UniversalTranslator'"
3. Navigate to: `/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/`
4. Select `GoogleService-Info.plist`
5. **IMPORTANT**: Make sure these options are checked:
   - ✅ Copy items if needed
   - ✅ Add to targets: UniversalTranslator

### Step 3: Verify Bundle ID
1. Click on your project in the navigator
2. Select your app target
3. Go to "General" tab
4. Verify Bundle Identifier is: `com.universaltranslator.app`

## Installing Firebase SDK

### Using Swift Package Manager (Recommended)

1. In Xcode: **File → Add Package Dependencies**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Click "Add Package"
4. Select these Firebase products:
   - ✅ FirebaseAnalytics
   - ✅ FirebaseAuth (optional)
   - ✅ FirebaseFirestore
   - ✅ FirebaseStorage

### Using CocoaPods (Alternative)

1. Close Xcode
2. Navigate to your iOS project directory
3. Create a Podfile:
```bash
cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS
pod init
```

4. Edit Podfile:
```ruby
platform :ios, '15.0'
use_frameworks!

target 'UniversalTranslator' do
  pod 'Firebase/Analytics'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Auth'
end
```

5. Install pods:
```bash
pod install
```

6. Open the `.xcworkspace` file (not `.xcodeproj`)

## Quick Verification

### Build and Run Test
1. Select a simulator (iPhone 14 or later)
2. Press Cmd+B to build
3. Check for any errors
4. If successful, you should see "Build Succeeded"

### Check Firebase Configuration
Look for this in the console when app launches:
```
✅ Firebase initialized successfully
```

## Troubleshooting

### Common Issues

**Issue**: "No such module 'Firebase'"
- **Solution**: Make sure you added Firebase SDK via SPM or CocoaPods

**Issue**: "Could not find a valid GoogleService-Info.plist"
- **Solution**: Ensure the plist file is added to your app target

**Issue**: Bundle ID mismatch
- **Solution**: Change your app's bundle ID to `com.universaltranslator.app`

**Issue**: Build fails with architecture errors
- **Solution**: Clean build folder (Cmd+Shift+K) and rebuild

## Next Steps

1. ✅ GoogleService-Info.plist added to project
2. ✅ Firebase SDK installed
3. ✅ Bundle ID verified
4. → Initialize Firebase in AppDelegate.swift
5. → Create UI for translation
6. → Connect to Cloud Run API