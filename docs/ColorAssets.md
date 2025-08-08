# Color Assets Configuration for Xcode

## Required Color Assets in Asset Catalog

Add these color assets to your `Assets.xcassets` folder in Xcode for proper dark/light mode support:

### 1. AppPrimary
- **Light Mode**: RGB(0, 153, 102) - #009966 (Teal)
- **Dark Mode**: RGB(0, 179, 119) - #00B377 (Lighter Teal)

### 2. AppSecondary  
- **Light Mode**: RGB(0, 102, 191) - #0066BF (Blue)
- **Dark Mode**: RGB(0, 122, 255) - #007AFF (System Blue)

### 3. AppAccent
- **Light Mode**: RGB(0, 153, 102) - #009966 (Teal)
- **Dark Mode**: RGB(0, 179, 119) - #00B377 (Lighter Teal)

### 4. RecordingColor
- **Light Mode**: RGB(242, 67, 54) - #F24336 (Red)
- **Dark Mode**: RGB(255, 89, 76) - #FF594C (Lighter Red)

### 5. SuccessColor
- **Light Mode**: RGB(76, 175, 80) - #4CAF50 (Green)
- **Dark Mode**: RGB(102, 198, 106) - #66C66A (Lighter Green)

### 6. ProcessingColor
- **Light Mode**: RGB(33, 150, 243) - #2196F3 (Blue)
- **Dark Mode**: RGB(64, 170, 255) - #40AAFF (Lighter Blue)

### 7. ErrorColor
- **Light Mode**: RGB(244, 67, 54) - #F44336 (Red)
- **Dark Mode**: RGB(255, 105, 97) - #FF6961 (Coral Red)

### 8. WarningColor
- **Light Mode**: RGB(255, 152, 0) - #FF9800 (Orange)
- **Dark Mode**: RGB(255, 179, 64) - #FFB340 (Lighter Orange)

## How to Add Color Assets in Xcode:

1. Open your Xcode project
2. Navigate to `Assets.xcassets`
3. Right-click and select "New Color Set"
4. Name it according to the colors above (e.g., "AppPrimary")
5. In the Attributes Inspector, set "Appearances" to "Any, Dark"
6. Set the appropriate RGB values for both light and dark modes
7. Repeat for all color assets

## Advantages of This Approach:

- ✅ **Automatic adaptation** to system appearance changes
- ✅ **Proper contrast ratios** in both light and dark modes
- ✅ **Accessibility compliance** with WCAG guidelines
- ✅ **Future-proof** design system
- ✅ **Consistent branding** across the app
- ✅ **Easy maintenance** - change colors in one place