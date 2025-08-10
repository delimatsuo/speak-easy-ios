# Universal Translator Watch App - Product Requirements Document

## Executive Summary
Add a watchOS companion app to the existing Universal Translator iOS app, enabling users to record audio on their Apple Watch and receive translations directly on their wrist. The Watch app leverages the existing iPhone pipeline for processing while providing a seamless, privacy-focused experience.

## Objectives
- Enable hands-free translation directly from Apple Watch
- Leverage existing iPhone infrastructure (no backend changes)
- Maintain zero conversation retention policy
- Provide quick access to translation without pulling out iPhone
- Support 15-30 second recordings for practical conversations

## Architecture Overview

### Repository Structure
```
UniversalTranslatorApp/
├── iOS/                    # Existing iPhone app
├── watchOS/               # New Watch app code
│   ├── ContentView.swift
│   ├── AudioManager.swift
│   ├── ConnectivityManager.swift
│   └── Info.plist
├── Shared/                # Shared code
│   ├── Models/
│   │   ├── TranslationRequest.swift
│   │   └── TranslationResponse.swift
│   └── Utilities/
│       └── AudioConstants.swift
└── UniversalTranslator.xcodeproj
```

### Bundle Identifiers
- iPhone App: `com.universaltranslator.app`
- Watch App: `com.universaltranslator.app.watchkitapp`
- Watch Extension: `com.universaltranslator.app.watchkitextension`

## Core Features

### 1. Audio Recording (Watch)
- **Duration**: 15-30 seconds maximum
- **Format**: AAC/M4A at 44.1kHz
- **Storage**: Temporary files only (auto-cleanup)
- **Trigger**: Crown press or tap gesture
- **Visual Feedback**: Animated recording indicator

### 2. WatchConnectivity Transport
- **Method**: File transfer for audio >100KB, data messages for <100KB
- **Chunking**: Support for large audio files
- **Reliability**: Queue and retry on connection loss
- **Timeout**: 30 seconds for complete round-trip

### 3. Translation Pipeline (iPhone)
- **Reuse**: Existing TranslationService
- **Credits**: Deduct from user's balance
- **STT**: Local or server (existing logic)
- **Translation**: Existing API pipeline
- **TTS**: Return audio bytes to Watch

### 4. Audio Playback (Watch)
- **Speaker**: Use Watch speaker
- **Haptics**: Gentle tap when ready
- **Volume**: Respect system volume
- **Interruption**: Handle calls/notifications

### 5. UI States
```
Idle → Recording → Sending → Processing → Playing → Idle
                      ↓            ↓           ↓
                   Error ←─────────┴───────────┘
```

## User Interface

### Main Screen Components
1. **Language Selector** (Top)
   - Source → Target languages
   - Sync with iPhone selection
   - Swipe to change

2. **Recording Button** (Center)
   - Large tap target (60x60 pts)
   - Visual states: Ready/Recording/Processing
   - Haptic feedback

3. **Status Display** (Bottom)
   - Credits remaining (synced)
   - Connection status
   - Error messages

### Visual Design
- **Colors**: Match iPhone app theme
- **Typography**: SF Pro Rounded
- **Animations**: Smooth 60fps
- **Dark Mode**: Full support

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create watchOS target in Xcode
- [ ] Set up folder structure
- [ ] Configure signing/provisioning
- [ ] Basic UI with state machine
- [ ] WatchConnectivity setup

### Phase 2: Audio Pipeline (Week 2)
- [ ] Audio recording on Watch
- [ ] File transfer to iPhone
- [ ] iPhone processing integration
- [ ] Response handling on Watch
- [ ] Audio playback on Watch

### Phase 3: Polish (Week 3)
- [ ] Error handling & recovery
- [ ] Performance optimization
- [ ] Credits sync & display
- [ ] Language selection sync
- [ ] Haptic feedback

### Phase 4: Testing (Week 4)
- [ ] Device testing (various Watch models)
- [ ] Connection reliability
- [ ] Battery impact assessment
- [ ] Edge cases & error scenarios
- [ ] TestFlight deployment

## Technical Specifications

### Audio Recording (Watch)
```swift
// Configuration
let settings = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    AVEncoderBitRateKey: 64000  // Lower for Watch
]
```

### WatchConnectivity Setup
```swift
// Watch Side
class ConnectivityManager: NSObject, WCSessionDelegate {
    func sendAudioToPhone(url: URL) {
        if WCSession.default.isReachable {
            WCSession.default.transferFile(url, metadata: [...])
        }
    }
}

// iPhone Side  
class WatchSessionManager: NSObject, WCSessionDelegate {
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Process with existing pipeline
    }
}
```

### Data Models (Shared)
```swift
struct TranslationRequest: Codable {
    let audioData: Data?
    let audioURL: URL?
    let sourceLanguage: String
    let targetLanguage: String
    let requestId: UUID
}

struct TranslationResponse: Codable {
    let translatedText: String
    let audioData: Data?
    let error: String?
    let requestId: UUID
}
```

## Privacy & Security

### Data Handling
- **No Storage**: Zero conversation retention
- **Temporary Files**: Auto-delete after transfer
- **Memory Only**: Translation results in memory
- **No Analytics**: No conversation tracking

### Permissions
- **Microphone**: Required for recording
- **Network**: Via paired iPhone only
- **Notifications**: Optional for completion

## Performance Requirements

### Response Times
- **Recording Start**: <100ms
- **Transfer to iPhone**: <2s for 30s audio
- **Total Round-trip**: <10s typical, 30s max
- **Playback Start**: <500ms after receive

### Resource Usage
- **Memory**: <50MB active
- **Battery**: <5% per hour active use
- **Storage**: <10MB temporary
- **Network**: Via iPhone only

## Error Handling

### Connection Errors
- "iPhone not reachable" → Queue for later
- "Transfer failed" → Retry 3x with backoff
- "Timeout" → Show error, allow retry

### Audio Errors
- "Microphone denied" → Show settings prompt
- "Recording failed" → Clear state, show error
- "Playback failed" → Offer text-only

### Credit Errors
- "No credits" → Sync and show purchase option
- "Sync failed" → Use cached value, warn user

## Testing Checklist

### Functional Tests
- [ ] Record 15s, 30s audio clips
- [ ] Transfer various file sizes
- [ ] Process all supported languages
- [ ] Play translated audio
- [ ] Handle interruptions

### Edge Cases
- [ ] iPhone app not installed
- [ ] iPhone app backgrounded/killed
- [ ] Watch on WiFi, iPhone on cellular
- [ ] Low battery scenarios
- [ ] Storage full scenarios

### Performance Tests
- [ ] Measure round-trip times
- [ ] Monitor memory usage
- [ ] Check battery drain
- [ ] Stress test with rapid requests

## Success Metrics

### User Experience
- **Round-trip Time**: <10s for 90% of requests
- **Success Rate**: >95% when connected
- **Crash Rate**: <0.1%
- **User Rating**: >4.5 stars

### Technical Metrics
- **Memory Usage**: <50MB peak
- **Battery Impact**: <5% per hour
- **File Transfer Success**: >98%
- **Audio Quality**: Clear and audible

## Future Enhancements (Post-Launch)

1. **Complications**: Quick launch from watch face
2. **Siri Shortcuts**: "Translate this" voice command
3. **Offline Mode**: Basic phrases without iPhone
4. **History**: Recent translations (opt-in)
5. **Widgets**: Language switcher widget

## Appendix

### WatchOS Limitations
- No direct network access (must use iPhone)
- Limited background execution
- Smaller memory budget
- No direct Firebase access
- Restricted audio codec support

### Best Practices
- Use SwiftUI for Watch UI
- Minimize data transfer size
- Handle connection loss gracefully
- Provide clear visual feedback
- Test on real devices

### References
- [Apple WatchConnectivity Documentation](https://developer.apple.com/documentation/watchconnectivity)
- [watchOS Audio Guidelines](https://developer.apple.com/design/human-interface-guidelines/playing-audio#watchOS)
- [SwiftUI for watchOS](https://developer.apple.com/documentation/swiftui)

---

*Last Updated: January 2025*
*Version: 1.0*