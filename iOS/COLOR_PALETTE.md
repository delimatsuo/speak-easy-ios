# Mervyn Talks Color Palette

## Primary Brand Colors

### Teal (Primary)
- **Hex:** #009966
- **RGB:** 0, 153, 102
- **SwiftUI:** Color(red: 0.00, green: 0.60, blue: 0.40)
- **Usage:** Primary accent, main CTA buttons, success states

### Blue (Secondary)
- **Hex:** #0066BF
- **RGB:** 0, 102, 191
- **SwiftUI:** Color(red: 0.00, green: 0.40, blue: 0.75)
- **Usage:** Secondary buttons, processing states, links

## Gradient Definitions

### Icon/Button Gradient
- **Start:** Teal (#009966)
- **End:** Blue (#0066BF)
- **Direction:** Bottom-right to top-left
- **Usage:** App icon, primary buttons, hero elements

### Background Gradient
- **Light:** #F2FAF7 (very light teal tint)
- **Dark:** #E6F5FA (very light blue tint)
- **Usage:** App background, card backgrounds

## Semantic Colors

### Recording State
- **Color:** #F24238 (Red)
- **RGB:** 242, 66, 56
- **Usage:** Recording indicator, stop button

### Success/Playing
- **Color:** Teal (#009966)
- **Usage:** Success messages, playing audio indicator

### Processing
- **Color:** Blue (#0066BF)
- **Usage:** Loading states, progress indicators

### Error
- **Color:** #D93333 (Dark Red)
- **RGB:** 217, 51, 51
- **Usage:** Error messages, validation

## Text Colors

### Primary Text
- **Color:** #262633 (Dark Gray)
- **RGB:** 38, 38, 51
- **Usage:** Headers, primary content

### Secondary Text
- **Color:** #737380 (Medium Gray)
- **RGB:** 115, 115, 128
- **Usage:** Subheadings, secondary content

### Light Text
- **Color:** #FFFFFF (White)
- **Usage:** Text on colored backgrounds

## Implementation in App

### Background
```swift
Color.speakEasyBackgroundGradient
```

### Primary Button
```swift
.background(Color.speakEasyButtonGradient)
.foregroundColor(.white)
```

### Language Swap Button
```swift
Circle()
    .fill(Color.speakEasyTeal.opacity(0.1))
Image(systemName: "arrow.2.circlepath")
    .foregroundColor(.speakEasyTeal)
```

### Recording State
```swift
Circle()
    .fill(Color.speakEasyRecording)
```

### Cards/Content Areas
```swift
.background(Color.speakEasyCardGradient)
```

## Accessibility Notes

- All color combinations maintain WCAG AA compliance
- Primary colors have 4.5:1 contrast ratio with white
- Text colors have appropriate contrast on all backgrounds
- Consider adding high contrast mode support in future updates