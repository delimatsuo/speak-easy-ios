# Fix Watch App Pairing & Installation Issues

## Problem
When installing the Watch app, it triggers a reinstallation of the iPhone app. This is caused by missing App Group configuration that properly pairs the apps as companions.

## Solution: Configure App Groups

### Step 1: Add Entitlements Files to Xcode

#### For iPhone App:
1. In Xcode, select your **UniversalTranslator** target (iPhone app)
2. Go to the **Signing & Capabilities** tab
3. Click the **+ Capability** button
4. Add **App Groups** capability
5. Click the **+** under App Groups to add a new group
6. Enter: `group.com.universaltranslator.app.shared`
7. Xcode should automatically link to the entitlements file at `/iOS/UniversalTranslator.entitlements`

#### For Watch App:
1. Select your **UniversalTranslator Watch App** target
2. Go to the **Signing & Capabilities** tab
3. Click the **+ Capability** button
4. Add **App Groups** capability
5. Click the **+** under App Groups to add the same group
6. Enter: `group.com.universaltranslator.app.shared`
7. Xcode should automatically link to the entitlements file at `/watchOS/UniversalTranslator Watch App.entitlements`

### Step 2: Verify Bundle Identifiers
✅ Already configured correctly:
- iPhone: `com.universaltranslator.app`
- Watch: `com.universaltranslator.app.watchkitapp`

### Step 3: Update Provisioning Profiles
1. Go to **Signing & Capabilities** for both targets
2. Ensure **Automatically manage signing** is checked
3. Click **Try Again** if there are any signing errors
4. Xcode will regenerate provisioning profiles with App Group capability

### Step 4: Clean and Rebuild
1. **Product > Clean Build Folder** (⇧⌘K)
2. Delete apps from both iPhone and Watch
3. Build and run the iPhone app first
4. The Watch app should now appear in the Apple Watch app on iPhone
5. Install from there - it should not trigger iPhone reinstallation

## What This Fixes

1. **Proper App Pairing**: Apps are now recognized as companions
2. **No Reinstallation**: Installing Watch app won't trigger iPhone app reinstall
3. **Automatic Installation**: Watch app will appear in iPhone's Watch app
4. **Data Sharing**: Apps can share data through the App Group container
5. **WatchConnectivity**: Session will work more reliably

## Testing the Fix

1. Delete both apps from devices
2. Install iPhone app via Xcode
3. Open Apple Watch app on iPhone
4. Look for "Universal AI Translator" in the Available Apps section
5. Tap Install - should install without triggering iPhone reinstall
6. Both apps should maintain their connection

## If Issues Persist

1. **Check Developer Account**: Ensure App Groups are enabled for your App ID
2. **Regenerate Profiles**: In Xcode, uncheck and recheck "Automatically manage signing"
3. **Check Console**: Look for entitlement errors in device console
4. **TestFlight**: Try distributing via TestFlight for automatic installation

## Benefits of App Groups

- Shared UserDefaults between apps
- Shared file storage container
- Better WatchConnectivity reliability
- Proper companion app relationship
- Automatic installation support