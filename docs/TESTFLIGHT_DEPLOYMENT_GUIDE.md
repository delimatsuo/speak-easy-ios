# TestFlight Deployment Guide - Universal Translator v3.0.0

## Prerequisites

### 1. Apple Developer Account Setup
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] App Store Connect access configured
- [ ] Development Team ID obtained
- [ ] Signing certificates created

### 2. App Store Connect Preparation
- [ ] App created in App Store Connect
- [ ] Bundle ID registered: `com.universaltranslator.app`
- [ ] App information filled out
- [ ] Screenshots prepared (required sizes below)

### 3. Required Credentials
```bash
# Add to your .env or configure in CI/CD
DEVELOPMENT_TEAM="YOUR_TEAM_ID"
APP_STORE_CONNECT_API_KEY="YOUR_API_KEY"
APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
```

---

## Step-by-Step Deployment

### Step 1: Update Team ID
```bash
# Edit the deployment script
sed -i '' 's/YOUR_TEAM_ID/YOUR_ACTUAL_TEAM_ID/g' scripts/deploy_production.sh
```

### Step 2: Clean Build
```bash
cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Step 3: Run Deployment Script
```bash
./scripts/deploy_production.sh
```

### Step 4: Manual Xcode Archive (Alternative)

1. Open Xcode
2. Select "Any iOS Device (arm64)" as destination
3. Product → Archive
4. Wait for archive to complete
5. In Organizer → Distribute App
6. Select "App Store Connect"
7. Choose "Upload"
8. Follow prompts to upload

### Step 5: Configure TestFlight

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to TestFlight tab
4. Wait for build processing (15-30 minutes)
5. Fill out Export Compliance Information:
   - Uses Encryption: Yes (for HTTPS)
   - Exempt: Yes (standard encryption)

### Step 6: Add Test Information

**What to Test:**
```
Version 3.0.0 - Enterprise Edition

Please test the following new features:
1. OAuth 2.0 authentication (Google, Apple Sign In)
2. Apple Watch app with voice translation
3. Enhanced security features
4. Improved performance and stability

Focus Areas:
- Memory usage during long sessions
- Watch connectivity reliability
- Authentication flow smoothness
- Translation accuracy
- Offline message queuing
```

**Test Notes:**
```
Known Issues:
- None at this time

Requirements:
- iOS 15.0+
- watchOS 8.0+
- Microphone access for voice translation
```

### Step 7: Add Testers

#### Internal Testing (Immediate)
1. TestFlight → Internal Testing
2. Add up to 100 internal testers
3. No review required
4. Available immediately

#### External Testing (Review Required)
1. TestFlight → External Testing
2. Create a test group
3. Add up to 10,000 testers
4. Submit for Beta App Review
5. Wait 24-48 hours for approval

---

## Required App Store Assets

### Screenshots (All Required)
- **iPhone 6.7"**: 1290 × 2796 pixels
- **iPhone 6.5"**: 1242 × 2688 pixels  
- **iPhone 5.5"**: 1242 × 2208 pixels
- **iPad Pro 12.9"**: 2048 × 2732 pixels
- **Apple Watch**: 368 × 448 pixels

### App Information
- **App Name**: Universal Translator
- **Subtitle**: Speak Any Language Instantly
- **Keywords**: translator, voice, speech, language, universal
- **Description**: See RELEASE_NOTES_v3.0.0.md
- **Category**: Productivity
- **Age Rating**: 4+

### Privacy Policy
- Required for microphone access
- Required for data collection
- URL: Include in app and App Store listing

---

## Troubleshooting

### Common Issues

#### Archive Failed
```bash
# Clean and retry
xcodebuild clean -alltargets
rm -rf ~/Library/Developer/Xcode/DerivedData
pod install  # if using CocoaPods
```

#### Signing Issues
```bash
# Reset certificates
fastlane match nuke distribution  # if using fastlane
# Or manually in Xcode:
# Preferences → Accounts → Manage Certificates → Reset
```

#### Upload Failed
```bash
# Validate first
xcrun altool --validate-app -f path/to/app.ipa -t ios -u APPLE_ID -p APP_SPECIFIC_PASSWORD
```

#### Processing Stuck
- Wait up to 24 hours
- Contact App Store Connect support if longer

---

## TestFlight Links

Once uploaded, testers can join via:
1. **Public Link**: Generate in TestFlight → External Testing
2. **Email Invitation**: Automatic when adding testers
3. **Redemption Code**: For limited distribution

---

## Monitoring

### Crash Reports
- View in App Store Connect → TestFlight → Crashes
- Symbolicate with dSYMs from archive

### Feedback
- TestFlight → Feedback
- Respond to tester issues
- Track common problems

### Analytics
- App Store Connect → Analytics
- Monitor adoption rates
- Track feature usage

---

## Production Release Checklist

After successful TestFlight testing:

- [ ] All critical bugs fixed
- [ ] Performance metrics acceptable
- [ ] Security audit passed
- [ ] Accessibility tested
- [ ] Localization complete
- [ ] App Store assets ready
- [ ] Privacy policy updated
- [ ] Terms of service ready
- [ ] Support URL active
- [ ] Marketing materials prepared

---

## Contact

For deployment issues:
- Apple Developer Support: https://developer.apple.com/support/
- App Store Connect Help: https://help.apple.com/app-store-connect/

---

**Ready for TestFlight!** 🚀

Once testing is complete and feedback incorporated, submit for App Store review.