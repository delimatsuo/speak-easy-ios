# Deployment Checklist for Device Testing

## Pre-Deployment Verification

### ✅ Code Review Completed
- [x] Apple Watch integration code reviewed
- [x] WatchSessionManager implementation verified
- [x] Audio transfer between devices confirmed
- [x] Error handling and logging in place

### ✅ Build Configuration
- [x] Entitlements configured for both iOS and watchOS
- [x] App Groups enabled: `group.com.universaltranslator.app.shared`
- [x] Bundle IDs properly configured:
  - iOS: `com.universaltranslator.app`
  - Watch: `com.universaltranslator.app.watchkitapp`

## Device Testing Requirements

### 📱 iPhone Requirements
- iOS 17.0 or later
- Developer mode enabled
- Provisioning profile installed
- Device registered in Apple Developer account

### ⌚ Apple Watch Requirements
- watchOS 10.0 or later
- Paired with test iPhone
- Developer mode enabled
- Watch app provisioning profile

## Deployment Steps

### 1. Prepare Development Environment
```bash
# Clean build folder
Product > Clean Build Folder (⇧⌘K)

# Update provisioning profiles
Xcode > Settings > Accounts > Download Manual Profiles
```

### 2. Configure Signing
1. Open project in Xcode
2. Select UniversalTranslator target
3. Signing & Capabilities tab
4. Ensure "Automatically manage signing" is checked
5. Select your Development Team
6. Repeat for Watch App target

### 3. Build and Deploy to iPhone
1. Connect iPhone via USB
2. Select iPhone as destination
3. Build and Run (⌘R)
4. Trust developer certificate on device if prompted
   - Settings > General > VPN & Device Management

### 4. Install Watch App
1. Open Apple Watch app on iPhone
2. Navigate to "Available Apps"
3. Find "Universal AI Translator"
4. Tap "Install"
5. Wait for installation to complete

### 5. Verify Installation
- [ ] iPhone app launches successfully
- [ ] Watch app appears on Apple Watch
- [ ] WatchConnectivity session activates
- [ ] Test basic translation flow

## Testing Scenarios

### Basic Functionality
1. **Credits Sync**
   - Launch both apps
   - Verify credits display on Watch
   - Test credit consumption

2. **Language Selection**
   - Change languages on iPhone
   - Verify sync to Watch
   - Test language switching on Watch

3. **Audio Recording**
   - Record on Watch
   - Verify transfer to iPhone
   - Check translation response

4. **Error Handling**
   - Test with no internet
   - Test with low credits
   - Test with invalid audio

### Performance Testing
- Monitor memory usage
- Check battery consumption
- Verify response times
- Test background/foreground transitions

## Troubleshooting

### Common Issues

#### Watch App Not Appearing
1. Restart both devices
2. Re-pair Watch if needed
3. Check provisioning profiles
4. Verify App Groups configuration

#### WatchConnectivity Issues
1. Check session activation
2. Verify both apps are running
3. Review console logs for errors
4. Test with simplified payload

#### Audio Transfer Failures
1. Check file size limits
2. Verify audio format compatibility
3. Monitor transfer queue
4. Test with shorter recordings

## Post-Deployment

### Monitoring
- Use Console app for device logs
- Monitor crash reports in Xcode
- Track performance metrics
- Gather user feedback

### Documentation Updates
- Record any configuration changes
- Document device-specific issues
- Update testing procedures
- Note performance observations

## TestFlight Distribution (Optional)

### Preparation
1. Archive build in Xcode
2. Upload to App Store Connect
3. Add internal testers
4. Submit for review if needed

### Testing
1. Install TestFlight app
2. Accept invitation
3. Install both apps
4. Report issues via TestFlight

## Sign-off

- [ ] All tests passed
- [ ] Performance acceptable
- [ ] No critical bugs
- [ ] Ready for user testing

---
Last Updated: August 22, 2025