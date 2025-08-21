# Apple Watch App Installation Guide

## Current Status
The Apple Watch companion app is fully implemented but requires manual installation due to Xcode configuration limitations.

## Installation Methods

### Method 1: Direct Installation (Recommended)
1. **Install iPhone App**
   - Select scheme: `UniversalTranslator`
   - Select your iPhone as destination
   - Run (⌘R)
   - Keep app open on iPhone

2. **Install Watch App**
   - Select scheme: `UniversalTranslator Watch App`
   - Select your Apple Watch as destination
   - Run (⌘R)
   - Wait for installation to complete

3. **Verify Connection**
   - iPhone app should show "Watch Connected"
   - Watch app should show "Connected" status

### Method 2: TestFlight Distribution
For production deployment:
1. Archive the iPhone app with Watch app included
2. Upload to App Store Connect
3. Distribute via TestFlight
4. Watch app will install automatically with iPhone app

## Troubleshooting

### Watch App Not Appearing
If the Watch app disappears after installation:
- Check signing certificates match between targets
- Verify bundle IDs follow pattern:
  - iPhone: `com.universaltranslator.app`
  - Watch: `com.universaltranslator.app.watchkitapp`

### Connection Issues
If apps don't connect:
1. Ensure both apps are running
2. Check iPhone console for:
   - `✅ iPhone: Session activated`
   - `isWatchAppInstalled: true`
3. Check Watch console for:
   - `✅ Watch: Session activated`
   - `📱 Watch: iPhone reachability: true`

### Recording Not Working
- Simulator: Microphone not supported, test on real device
- Device: Check microphone permissions in Settings

## Technical Details

### Why Manual Installation?
Modern Xcode (15+) handles Watch apps as separate targets rather than embedded extensions. This provides better flexibility but requires explicit installation during development.

### For App Store Release
The Watch app will be properly bundled when:
1. Creating an archive for App Store
2. Both targets are included in the archive
3. App Store Connect recognizes the Watch companion

## Features Working After Installation

✅ Language synchronization  
✅ Credit balance display  
✅ Voice recording (device only)  
✅ Translation processing via iPhone  
✅ Audio playback on Watch  
✅ Connection status indicators  

## Development Tips

1. **Always test on real devices** - Simulator has limitations
2. **Keep iPhone app in foreground** during initial testing
3. **Check both consoles** for debugging connection issues
4. **Use TestFlight** for beta testing with automatic installation

---

Last Updated: August 21, 2025