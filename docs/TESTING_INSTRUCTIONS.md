# Testing Instructions for Apple Watch Integration

## Quick Start

### 1. Open Project in Xcode
```bash
open -a Xcode UniversalTranslatorApp.xcworkspace
```

### 2. Configure Signing (if needed)
- Select each target (iPhone and Watch app)
- Go to Signing & Capabilities
- Ensure your team is selected
- Let Xcode manage signing automatically

### 3. Build and Run

#### For Simulator Testing:
1. Select "UniversalTranslatorApp" scheme
2. Choose iPhone 15 Pro simulator
3. Build and Run (⌘R)
4. The Watch app will be available in the paired Watch simulator

#### For Device Testing:
1. Connect your iPhone via USB
2. Select your iPhone as destination
3. Build and Run (⌘R)
4. Install Watch app from Apple Watch app on iPhone

## Features to Test

### 🎯 Core Features

1. **Watch → iPhone Audio Translation**
   - Open Watch app
   - Tap record button
   - Speak for 2-10 seconds
   - Release to send
   - Translation appears on Watch

2. **Credits Synchronization**
   - Check credits on iPhone
   - Open Watch app
   - Credits should match
   - Use translation
   - Credits update on both

3. **Language Settings**
   - Change source/target language on iPhone
   - Open Watch app
   - Languages should be synced
   - Test translation with new languages

### 📊 Debug Features

The implementation includes extensive logging:
- Watch app logs all operations
- iPhone logs session management
- Transfer status updates
- Error conditions

Use Console app to monitor logs:
1. Open Console app on Mac
2. Select your device
3. Filter by "UniversalTranslator"
4. Watch real-time logs

## Common Test Scenarios

### Scenario 1: First Time Setup
1. Install iPhone app
2. Launch and sign in
3. Open Apple Watch app
4. Find Universal AI Translator
5. Install Watch app
6. Launch Watch app
7. Verify connection

### Scenario 2: Audio Translation Flow
1. Ensure both apps are running
2. On Watch: tap record
3. Speak: "Hello, how are you?"
4. Release button
5. Wait for translation
6. Verify audio plays

### Scenario 3: Error Recovery
1. Put iPhone in airplane mode
2. Try recording on Watch
3. Should see error message
4. Re-enable network
5. Try again - should work

### Scenario 4: Background Operation
1. Start translation on Watch
2. Lower wrist (app backgrounds)
3. Raise wrist when notified
4. Translation should appear

## Troubleshooting

### Watch App Not Installing
- Ensure iPhone app is installed first
- Check Apple Watch app > General > Device Management
- Restart both devices
- Re-pair Watch if necessary

### No Translation Response
- Check iPhone app is running
- Verify network connection
- Check credits available
- Review Console logs

### Audio Not Playing
- Check Watch volume
- Ensure not in silent mode
- Test with iPhone speaker
- Verify audio data transfer

## Performance Metrics

Monitor these during testing:
- Response time: Should be < 5 seconds
- Audio quality: Clear and audible
- Memory usage: Watch app < 50MB
- Battery impact: Minimal during standby

## Reporting Issues

When reporting issues, include:
1. Device models and OS versions
2. Steps to reproduce
3. Console logs
4. Screenshots if relevant
5. Network conditions

## Success Criteria

✅ The integration is successful when:
- Watch app installs without reinstalling iPhone app
- Audio recordings transfer reliably
- Translations appear within 5 seconds
- Credits sync properly
- Error messages are clear
- App remains responsive

---
Ready for testing! The Apple Watch integration is complete and deployed.