# 🔐 Production Signing & App Store Connect Setup

## Overview
This guide covers setting up production code signing certificates and App Store Connect configuration for Universal AI Translator.

## 📋 Prerequisites

### Apple Developer Account
- ✅ Paid Apple Developer Program membership ($99/year)
- ✅ Team ID access
- ✅ App Store Connect access

### Required Information
- **App Name**: Universal AI Translator
- **Bundle ID**: `com.universaltranslator.app`
- **Team ID**: [Your Apple Team ID]
- **Apple ID**: [Your Apple ID email]

## 🔑 Step 1: Code Signing Certificates

### 1.1 Create App Store Distribution Certificate
```bash
# Open Xcode and navigate to:
# Xcode → Preferences → Accounts → [Your Apple ID] → Manage Certificates
# Click "+" and select "Apple Distribution"
```

### 1.2 Create App Store Provisioning Profile
1. Visit [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Profiles** → **+** (Add new)
4. Select **App Store** distribution
5. Choose your App ID: `com.universaltranslator.app`
6. Select your Distribution certificate
7. Download the `.mobileprovision` file

### 1.3 Configure Xcode Project
```bash
# In Xcode project settings:
# 1. Select "UniversalTranslator" target
# 2. Go to "Signing & Capabilities"
# 3. Set "Automatically manage signing" to OFF for Release
# 4. Select your Team
# 5. Choose the App Store provisioning profile
```

## 🏪 Step 2: App Store Connect Configuration

### 2.1 Create App Record
1. Visit [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **+** → **New App**
3. Fill in details:
   - **Platform**: iOS
   - **Name**: Universal AI Translator
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.universaltranslator.app
   - **SKU**: universal-ai-translator

### 2.2 App Information
```yaml
App Information:
  Name: Universal AI Translator
  Subtitle: Real-time voice translation
  Category: Productivity
  Secondary Category: Education
  Content Rights: No
```

### 2.3 Pricing and Availability
```yaml
Pricing:
  Price: Free
  Availability: All countries
  App Store Distribution: Available
```

### 2.4 App Privacy
```yaml
Privacy Policy URL: https://your-domain.com/privacy
Data Collection: 
  - Contact Info: Email addresses (for account support)
  - Usage Data: Product interaction (for app functionality)
  - Diagnostics: Crash data (for app improvement)
```

## 🛡️ Step 3: Security Configuration

### 3.1 Environment Variables for Production
Create `.env.production` file (NOT committed to git):
```bash
# Copy from scripts/production.env.template
cp scripts/production.env.template .env.production

# Fill in your actual values:
FIREBASE_PROJECT_ID=universal-translator-prod
FIREBASE_API_KEY=your-actual-firebase-key
GEMINI_API_KEY=your-actual-gemini-key
TEAM_ID=your-apple-team-id
```

### 3.2 Secure Keychain Configuration
```swift
// In production, API keys should come from:
// 1. Environment variables (preferred)
// 2. Secure keychain storage
// 3. Never from bundle files

// Example usage:
let apiKey = SecureConfig.shared.getAPIKey(for: "GoogleTranslateAPIKey")
```

## ⚙️ Step 4: Build Configuration

### 4.1 Production Build Script
```bash
#!/bin/bash
# scripts/build_production.sh

set -e

echo "🏗️ Building Universal AI Translator for App Store..."

# Set environment
export CONFIGURATION=Release
export ENVIRONMENT=production

# Source production environment
source .env.production

# Clean build folder
xcodebuild clean -project iOS/UniversalTranslator.xcodeproj -scheme UniversalTranslator

# Archive for App Store
xcodebuild archive \
  -project iOS/UniversalTranslator.xcodeproj \
  -scheme UniversalTranslator \
  -configuration Release \
  -archivePath ./build/UniversalTranslator.xcarchive \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="Universal AI Translator App Store"

echo "✅ Archive created successfully"
```

### 4.2 Upload to App Store Connect
```bash
# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/UniversalTranslator.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist scripts/ExportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app \
  -f ./build/export/UniversalTranslator.ipa \
  -u "your-apple-id@email.com" \
  -p "your-app-specific-password"
```

## 🔧 Step 5: Export Options Configuration

Create `scripts/ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

## ✅ Step 6: Verification Checklist

### Pre-Submission Checklist
- [ ] **Code signing**: Distribution certificate configured
- [ ] **Provisioning**: App Store profile selected
- [ ] **API keys**: Securely configured (not in bundle)
- [ ] **Firebase**: Production project configured
- [ ] **Environment**: Production environment variables set
- [ ] **Testing**: App tested on physical device
- [ ] **Metadata**: App Store Connect information complete
- [ ] **Privacy**: Privacy policy uploaded and configured
- [ ] **Screenshots**: All required screenshots uploaded

### Build Verification
```bash
# Verify archive
xcodebuild -showBuildSettings -archivePath ./build/UniversalTranslator.xcarchive

# Check for embedded provisioning
security cms -D -i ./build/UniversalTranslator.xcarchive/Products/Applications/UniversalTranslator.app/embedded.mobileprovision
```

## 🚨 Security Reminders

### ❌ Never Commit These Files:
- `.env.production`
- `.env.staging`
- `GoogleService-Info.plist` (production)
- `api_keys.plist`
- `*.mobileprovision`
- `*.p12`
- `*.p8`

### ✅ Always Use:
- Environment variables for API keys
- Keychain for secure storage
- App Store Connect for distribution
- Code signing for authentication

## 📞 Support

If you encounter issues:
1. Check Apple Developer documentation
2. Verify certificates in Keychain Access
3. Validate provisioning profiles
4. Test on physical device before upload

## 🔄 Automation (Optional)

For CI/CD pipeline, consider:
- Fastlane for automated builds
- GitHub Actions for continuous deployment
- App Store Connect API for metadata management

---

**Security Note**: This setup ensures production-grade security with proper separation of development and production environments.
