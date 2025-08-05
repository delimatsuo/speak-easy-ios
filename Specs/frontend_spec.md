# Frontend Specification - iPhone Universal Translator App

## 1. User Interface Layout

### 1.1 Main Screen Architecture

#### Screen Hierarchy
```
┌─────────────────────────────────┐
│      Status Bar (System)        │
├─────────────────────────────────┤
│    Navigation Bar (44pt)        │
│  [History] Universal [Settings] │
├─────────────────────────────────┤
│                                 │
│    Language Selection Area      │
│         (120pt height)          │
│                                 │
├─────────────────────────────────┤
│                                 │
│     Transcription Display       │
│         (Flexible)              │
│                                 │
├─────────────────────────────────┤
│                                 │
│     Translation Display         │
│         (Flexible)              │
│                                 │
├─────────────────────────────────┤
│                                 │
│    Record Button Area           │
│         (180pt height)          │
│                                 │
├─────────────────────────────────┤
│    Safe Area Bottom (34pt)      │
└─────────────────────────────────┘
```

### 1.2 Core UI Components

#### 1.2.1 Language Selection Buttons
- **Dimensions**: Two buttons, each 160pt × 60pt
- **Layout**: Horizontal arrangement with 8pt spacing
- **Visual Design**:
  - Rounded corners (16pt radius)
  - Semi-transparent background (0.95 opacity)
  - Drop shadow for depth
  - Border: 1pt, system accent color when selected
  
- **Content Structure**:
  ```
  ┌────────────────┐  ┌────────────────┐
  │ 🇺🇸 English    │⟷│ 🇪🇸 Spanish    │
  │    (Source)    │  │   (Target)     │
  └────────────────┘  └────────────────┘
  ```
  
- **Interactive Elements**:
  - Tap to open language selector
  - Long press for favorites menu
  - Center swap button (44pt × 44pt)

#### 1.2.2 Record/Speak Button
- **Primary Button**:
  - Size: 88pt diameter (standard), 100pt (active)
  - Position: Center-bottom, 40pt from safe area
  - Design: Gradient background with microphone SF Symbol
  - States:
    - Idle: Blue gradient (#007AFF to #0051D5)
    - Recording: Red gradient with pulse animation
    - Processing: Gray with activity indicator
    - Disabled: 0.4 opacity

- **Secondary Controls**:
  - Text input toggle: 44pt × 44pt, left of record
  - Play last translation: 44pt × 44pt, right of record
  - Both use SF Symbols with haptic feedback

#### 1.2.3 Text Display Areas

**Transcription Display**:
- **Container**: Rounded rectangle, 16pt padding
- **Background**: System background secondary
- **Typography**:
  - Font: SF Pro Display, Dynamic Type
  - Size: 17pt base (adjustable)
  - Color: Label (adaptive)
- **Features**:
  - Auto-scroll for long text
  - Copy button on tap-and-hold
  - Language label in top-left
  - Confidence indicator (if < 90%)

**Translation Display**:
- **Container**: Rounded rectangle, 16pt padding
- **Background**: Accent color at 0.1 opacity
- **Typography**:
  - Font: SF Pro Display Semibold
  - Size: 19pt base (adjustable)
  - Color: Label (adaptive)
- **Features**:
  - Pronunciation guide below (optional)
  - Audio playback button
  - Share button
  - Alternative translations expandable

### 1.3 Visual Hierarchy

1. **Primary Focus**: Record button (largest, centered)
2. **Secondary**: Translation display (accent background)
3. **Tertiary**: Language selectors (top position)
4. **Supporting**: Transcription, controls, navigation

## 2. User Flow

### 2.1 Two-Way Conversation Flow

#### Step-by-Step Interaction

**Phase 1: User A Speaks**
1. User A taps record button
2. Button animates to recording state (red pulse)
3. Waveform visualization appears
4. User speaks in Language 1
5. Release button or auto-stop after silence
6. Local iOS Speech Recognition processes audio
7. Transcribed text appears immediately
8. Loading indicator shows API processing

**Phase 2: Translation Delivery**
1. Gemini API returns translation
2. Translation text displays with fade-in
3. Audio automatically plays (if enabled)
4. Speaker icon animates during playback
5. Record button returns to idle state

**Phase 3: User B Responds**
1. User B taps record button
2. Languages auto-swap (configurable)
3. User B speaks in Language 2
4. Same transcription process
5. Translation plays in Language 1
6. Conversation continues

### 2.2 Alternative Input Flows

#### Text Input Mode
1. Tap keyboard icon (left of record)
2. Keyboard slides up with input field
3. Type or paste text
4. Tap "Translate" on keyboard
5. Follow same translation flow

#### Voice Command Mode
1. "Hey Siri, translate to Spanish"
2. App launches in recording mode
3. Auto-starts recording
4. Processes and translates
5. Plays translation

### 2.3 Conversation Management

**Auto-Detection Features**:
- Silence detection (2-second threshold)
- Language auto-detection option
- Speaker change detection
- Conversation mode toggle

**Manual Controls**:
- Tap to stop recording early
- Swipe to clear current translation
- Pull-to-refresh for new session
- Shake to undo last action

## 3. Language Selection

### 3.1 Language Selector Design

#### Modal Presentation
```
┌─────────────────────────────────┐
│         Select Language         │
├─────────────────────────────────┤
│ [🔍 Search languages...]        │
├─────────────────────────────────┤
│ ⭐ Favorites                    │
│   🇺🇸 English                   │
│   🇪🇸 Spanish                   │
│   🇫🇷 French                    │
├─────────────────────────────────┤
│ 🕐 Recent                      │
│   🇩🇪 German                    │
│   🇯🇵 Japanese                  │
├─────────────────────────────────┤
│ 🌍 All Languages               │
│   🇸🇦 Arabic                    │
│   🇧🇬 Bulgarian                │
│   🇨🇳 Chinese (Simplified)     │
│   🇹🇼 Chinese (Traditional)    │
│   [... scrollable list]        │
└─────────────────────────────────┘
```

### 3.2 Language Features

#### Quick Access
- **Favorites**: Star icon to save up to 5 languages
- **Recent**: Last 5 used languages
- **Search**: Real-time filtering by name or code
- **Categories**: Regional groupings option

#### Visual Elements
- **Flags**: 24pt emoji flags for recognition
- **Language Names**: Localized in current UI language
- **Native Names**: Shown as subtitle
- **Offline Indicator**: Download icon if available offline

### 3.3 Language Swap Interaction

**Swap Button Behavior**:
1. Single tap: Instant language swap
2. Animation: 180° rotation with fade
3. Haptic: Medium impact feedback
4. Visual: Brief highlight effect

**Smart Features**:
- Auto-swap in conversation mode
- Remember swap preferences
- Gesture support (two-finger swipe)

## 4. Visual Feedback

### 4.1 Recording State

#### Visual Indicators
- **Button Changes**:
  - Color: Blue → Red gradient
  - Size: 88pt → 100pt (smooth scale)
  - Icon: Microphone → Waveform animation
  
- **Waveform Visualization**:
  - Position: Above record button
  - Height: 60pt
  - Style: Real-time amplitude bars
  - Color: Matches button state

- **Screen Effects**:
  - Subtle dim of non-essential elements
  - Red recording indicator in status bar
  - Proximity sensor activation

### 4.2 Processing State

#### Loading Animations
- **Primary Indicator**: 
  - Three dots with sequential fade
  - Position: Center of translation area
  - Timing: 0.4s per dot cycle

- **Progress Feedback**:
  - Estimated time remaining (if > 2s)
  - Network activity indicator
  - Subtle skeleton screen

### 4.3 Playback State

#### Audio Playback Indicators
- **Speaker Animation**:
  - Radiating waves from speaker icon
  - Synchronized with audio amplitude
  - Color: System blue

- **Progress Bar**:
  - Thin line below translation
  - Real-time playback position
  - Tap to scrub

### 4.4 Success States

#### Completion Feedback
- **Visual**:
  - Green checkmark fade-in (0.3s)
  - Subtle bounce animation
  - Background color pulse

- **Haptic**:
  - Success pattern (light impact)
  - Different for each action type

## 5. Accessibility Considerations

### 5.1 VoiceOver Support

#### Screen Reader Optimization
- **Labels**: Descriptive labels for all controls
- **Hints**: Context-specific action hints
- **Announcements**: State changes announced
- **Grouping**: Logical element grouping
- **Navigation**: Rotor support for quick navigation

#### Custom Actions
```swift
// Example VoiceOver custom actions
.accessibilityElement(children: .combine)
.accessibilityLabel("Translate from English to Spanish")
.accessibilityHint("Double tap to start recording")
.accessibilityCustomAction("Switch languages") { 
    swapLanguages() 
}
```

### 5.2 Dynamic Type Support

#### Text Scaling
- **Supported Sizes**: xSmall to xxxLarge
- **Layout Adaptation**:
  - Vertical stacking at larger sizes
  - Scrollable content areas
  - Maintained touch targets (44pt minimum)

#### Implementation
```swift
Text(translatedText)
    .font(.body)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .minimumScaleFactor(0.7)
    .lineLimit(nil)
```

### 5.3 Visual Accessibility

#### High Contrast Mode
- **Increased Contrast**: Borders and separators
- **Reduced Transparency**: Solid backgrounds
- **Bold Text**: Heavier font weights
- **Button Shapes**: Visible button outlines

#### Color Accessibility
- **Color Blind Safe**: Patterns + colors
- **Contrast Ratios**: WCAG AAA compliance
- **Dark Mode**: Full adaptive color system

### 5.4 Motor Accessibility

#### Touch Accommodations
- **Touch Targets**: Minimum 44pt × 44pt
- **Spacing**: 8pt minimum between targets
- **Dwell Control**: Long press alternatives
- **Shake to Undo**: Configurable sensitivity

### 5.5 Haptic Feedback

#### Feedback Patterns
- **Recording Start**: Heavy impact
- **Recording Stop**: Medium impact
- **Translation Ready**: Light impact
- **Error**: Notification feedback
- **Button Taps**: Selection feedback

## 6. Platform Specifics (iOS/iPhone)

### 6.1 SwiftUI Implementation

#### Core Components
```swift
struct TranslationView: View {
    @StateObject var viewModel: TranslationViewModel
    @Environment(\.dynamicTypeSize) var dynamicType
    
    var body: some View {
        VStack(spacing: 16) {
            LanguageSelectionBar()
            TranscriptionDisplay()
            TranslationDisplay()
            RecordButton()
        }
        .safeAreaInset(edge: .bottom) {
            ControlBar()
        }
    }
}
```

### 6.2 iOS Design Patterns

#### Navigation
- **Style**: Large title navigation bar
- **Behavior**: Scroll-to-hide option
- **Actions**: SF Symbol bar buttons

#### Gestures
- **Swipe Down**: Dismiss keyboard
- **Swipe Left/Right**: Navigate history
- **Pinch**: Adjust text size
- **Long Press**: Context menus

### 6.3 Dynamic Island Support

#### Live Activity
```swift
struct TranslationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TranslationAttributes.self) {
            // Compact view
            HStack {
                Image(systemName: "mic.fill")
                Text("Translating...")
                    .font(.caption)
            }
        } dynamicIsland: { context in
            // Expanded view
            DynamicIsland {
                // Leading region
                Image(systemName: "translate")
                
                // Trailing region  
                Text(context.state.targetLanguage)
                
                // Bottom region
                Text(context.state.translatedText)
                    .lineLimit(2)
            }
        }
    }
}
```

### 6.4 Orientation Support

#### Portrait Layout
- Standard vertical stack
- Full-width controls
- Optimized for one-handed use

#### Landscape Layout
- Side-by-side text areas
- Floating record button
- Compact language selectors
- Hidden navigation bar

### 6.5 iOS-Specific Features

#### System Integration
- **Shortcuts App**: Custom translation shortcuts
- **Widgets**: Home screen translation widget
- **App Clips**: Quick translate without install
- **Handoff**: Continue on other devices

## 7. Error States

### 7.1 Network Errors

#### No Internet Connection
```
┌─────────────────────────────────┐
│                                 │
│         📡                     │
│    No Internet Connection       │
│                                 │
│  Translation requires internet  │
│  Check your connection and      │
│        try again                │
│                                 │
│     [Try Again]  [Offline]      │
│                                 │
└─────────────────────────────────┘
```

**Offline Mode Fallback**:
- Show available offline languages
- Access translation history
- Save for later translation

### 7.2 Speech Recognition Errors

#### STT Failure Handling
```
┌─────────────────────────────────┐
│                                 │
│         🎤                     │
│   Could Not Recognize Speech    │
│                                 │
│   Please try speaking again     │
│   or use text input instead     │
│                                 │
│   [Try Again]  [Type Instead]   │
│                                 │
└─────────────────────────────────┘
```

**Recovery Options**:
- Retry with adjusted settings
- Switch to text input
- Check microphone permissions

### 7.3 API Errors

#### Gemini API Error States

**Rate Limiting**:
```
┌─────────────────────────────────┐
│                                 │
│         ⏳                     │
│     Too Many Requests           │
│                                 │
│   Please wait 30 seconds        │
│      before trying again        │
│                                 │
│        [23s remaining]          │
│                                 │
└─────────────────────────────────┘
```

**Service Unavailable**:
```
┌─────────────────────────────────┐
│                                 │
│         🔧                     │
│  Translation Service Error      │
│                                 │
│  Service temporarily unavailable│
│    Please try again later       │
│                                 │
│  [Retry]  [Report Issue]        │
│                                 │
└─────────────────────────────────┘
```

### 7.4 Audio Playback Errors

#### Playback Failure
- Fallback to text-only display
- Show phonetic pronunciation
- Offer download for offline play
- Manual replay button

### 7.5 Error Recovery

#### Automatic Recovery
- Auto-retry for transient failures (3 attempts)
- Exponential backoff (1s, 2s, 4s)
- Queue management for rate limits
- Cache successful translations

#### Manual Recovery
- Clear, actionable error messages
- One-tap retry functionality
- Alternative input methods
- Contact support option

## 8. Key Deliverables/Screens

### 8.1 Main Translation Screen

#### Components Checklist
- [ ] Navigation bar with history/settings
- [ ] Language selection area
- [ ] Transcription display
- [ ] Translation display
- [ ] Record button with states
- [ ] Control bar with secondary actions
- [ ] Error overlay system

### 8.2 Language Selection Modal

#### Features
- [ ] Search functionality
- [ ] Favorites section
- [ ] Recent languages
- [ ] Full language list
- [ ] Offline availability indicators
- [ ] Selection confirmation

### 8.3 Settings Screen

#### Sections
```
Settings
├── Account
│   ├── Sign In / Profile
│   ├── Subscription
│   └── Sync Settings
├── Translation
│   ├── Default Languages
│   ├── Auto-detect Language
│   ├── Conversation Mode
│   └── Translation Quality
├── Speech
│   ├── Voice Selection
│   ├── Speech Rate
│   ├── Auto-play Translation
│   └── Recognition Language
├── Display
│   ├── Theme (Light/Dark/Auto)
│   ├── Text Size
│   ├── High Contrast
│   └── Reduce Motion
├── Offline
│   ├── Downloaded Languages
│   ├── Storage Management
│   └── Auto-download
├── Privacy
│   ├── Data Collection
│   ├── History Settings
│   └── Clear Cache
└── About
    ├── Version Info
    ├── Terms of Service
    ├── Privacy Policy
    └── Support
```

### 8.4 Conversation History

#### List View Design
```
┌─────────────────────────────────┐
│      Conversation History       │
├─────────────────────────────────┤
│ [🔍 Search conversations...]    │
├─────────────────────────────────┤
│ Today                           │
│ ┌─────────────────────────────┐ │
│ │ English → Spanish   2:30 PM │ │
│ │ "Where is the station?"     │ │
│ │ "¿Dónde está la estación?"  │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ French → English   11:45 AM │ │
│ │ "Bonjour, comment..."       │ │
│ │ "Hello, how are you?"       │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ Yesterday                       │
│ [... more items]               │
└─────────────────────────────────┘
```

### 8.5 Onboarding Screens

#### Screen Flow
1. **Welcome**: App value proposition
2. **Permissions**: Microphone, speech recognition
3. **Language Setup**: Select primary languages
4. **Feature Highlights**: Key features tour
5. **Ready**: Start translating

#### Design Principles
- Minimal text, visual communication
- Skip option always visible
- Progress indicator
- Smooth transitions

### 8.6 Error State Overlays

#### Toast Notifications
- Position: Top or bottom based on context
- Duration: 3 seconds (adjustable)
- Style: Blurred background, high contrast text
- Actions: Dismiss, retry, or learn more

#### Full-Screen Errors
- Used for critical failures only
- Clear illustration
- Descriptive message
- Recovery actions
- Support contact option

## 9. Animation & Transitions

### 9.1 Core Animations

#### Record Button
```swift
// Pulse animation while recording
.scaleEffect(isRecording ? 1.15 : 1.0)
.animation(
    .easeInOut(duration: 0.6)
    .repeatForever(autoreverses: true),
    value: isRecording
)
```

#### Text Appearance
```swift
// Fade and slide for new translations
.transition(.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .top)),
    removal: .opacity
))
```

### 9.2 Micro-interactions

- Button taps: Scale 0.95 with spring
- Language swap: 3D rotation effect
- Loading dots: Staggered fade
- Success checkmark: Draw path animation

## 10. Performance Specifications

### 10.1 Responsiveness Targets

- App launch: < 1 second
- Button response: < 50ms
- Language switch: < 100ms
- Keyboard appearance: < 200ms
- Screen transitions: 60 fps

### 10.2 Memory Management

- Image caching: 50MB limit
- Translation history: 500 items max
- Audio buffer: 10MB
- Memory warnings: Graceful degradation

### 10.3 Battery Optimization

- Reduce animations on low power
- Pause background processes
- Efficient network requests
- Audio session management

## 11. Testing Requirements

### 11.1 UI Testing Checklist

#### Functional Testing
- [ ] All buttons respond correctly
- [ ] Language selection works
- [ ] Recording captures audio
- [ ] Translations display properly
- [ ] History saves and loads
- [ ] Settings persist

#### Visual Testing
- [ ] All iPhone models (SE to Pro Max)
- [ ] iOS 15+ compatibility
- [ ] Light and dark modes
- [ ] Dynamic type sizes
- [ ] Landscape orientation
- [ ] Accessibility modes

### 11.2 Usability Testing

#### Test Scenarios
1. First-time user completes translation
2. Switch between 5 language pairs
3. Use in noisy environment
4. Recover from errors
5. Navigate with VoiceOver
6. One-handed operation

### 11.3 Performance Testing

- 1000 translations without crash
- 1 hour continuous use
- Background/foreground transitions
- Memory pressure scenarios
- Network interruption recovery

## 12. Localization

### 12.1 Supported UI Languages

Initial release:
- English
- Spanish  
- French
- German
- Japanese
- Chinese (Simplified)

### 12.2 Localization Guidelines

- Use iOS localization system
- Accommodate 200% text expansion
- RTL language support
- Cultural icon adaptation
- Date/time format localization

---

**Document Version**: 1.0  
**Last Updated**: 2025-08-03  
**Platform**: iOS 15.0+  
**Device Support**: iPhone SE (2nd gen) and later  
**Status**: Ready for Development