//
//  ModernLanguageSelector.swift
//  Mervyn Talks
//
//  Professional language selector with full language names and flags
//

import SwiftUI

struct ModernLanguageSelector: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let title: String
    let isSource: Bool
    
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Layout.smallSpacing) {
            // Title Label
            Text(title)
                .font(.system(size: DesignConstants.Typography.languageLabelSize, 
                            weight: DesignConstants.Typography.languageLabelWeight))
                .foregroundColor(DesignConstants.Colors.secondaryText)
                .accessibilityHeading(.h3)
            
            // Language Selection Button
            Button(action: { showingPicker = true }) {
                HStack(spacing: DesignConstants.Layout.elementSpacing) {
                    // Flag
                    if let selectedLang = languages.first(where: { $0.code == selectedLanguage }) {
                        Text(selectedLang.flag)
                            .font(.system(size: DesignConstants.Sizing.flagSize))
                        
                        // Language Name (FULL NAME - not truncated!)
                        Text(selectedLang.name)
                            .font(.system(size: DesignConstants.Typography.languageNameSize, 
                                        weight: DesignConstants.Typography.languageNameWeight))
                            .foregroundColor(DesignConstants.Colors.primaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text("Select Language")
                            .font(.system(size: DesignConstants.Typography.languageNameSize, 
                                        weight: DesignConstants.Typography.languageNameWeight))
                            .foregroundColor(DesignConstants.Colors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    // Dropdown Arrow
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignConstants.Colors.secondaryText)
                        .rotationEffect(.degrees(showingPicker ? 180 : 0))
                        .animation(DesignConstants.Animations.quick, value: showingPicker)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(minWidth: DesignConstants.Sizing.languageSelectorMinWidth,
                       minHeight: DesignConstants.Sizing.languageSelectorHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignConstants.Colors.languageSelectorBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignConstants.Colors.primary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("\(title): \(languages.first(where: { $0.code == selectedLanguage })?.name ?? "None selected")")
            .accessibilityHint("Tap to select a different language")
        }
        .sheet(isPresented: $showingPicker) {
            if #available(iOS 16.0, *) {
                LanguagePickerSheet(
                    selectedLanguage: $selectedLanguage,
                    languages: languages,
                    title: title,
                    isPresented: $showingPicker
                )
                .presentationDetents([.medium, .large])
            } else {
                LanguagePickerSheet(
                    selectedLanguage: $selectedLanguage,
                    languages: languages,
                    title: title,
                    isPresented: $showingPicker
                )
            }
        }
    }
}

// MARK: - Language Picker Sheet

struct LanguagePickerSheet: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let title: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(languages, id: \.code) { language in
                LanguagePickerRow(
                    language: language,
                    isSelected: language.code == selectedLanguage,
                    onSelect: {
                        withAnimation(DesignConstants.Animations.gentle) {
                            selectedLanguage = language.code
                        }
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        isPresented = false
                    }
                )
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .modifier(DetentsIfAvailable())
    }
}
// Wrapper modifier to apply presentationDetents only when available (iOS 16+)
private struct DetentsIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}


// MARK: - Language Picker Row

struct LanguagePickerRow: View {
    let language: Language
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 28))
                
                // Language Name
                Text(language.name)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(DesignConstants.Colors.primaryText)
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignConstants.Colors.primary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(isSelected ? DesignConstants.Colors.primaryLight : Color.clear)
        .accessibilityLabel(language.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#if DEBUG
struct ModernLanguageSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            ModernLanguageSelector(
                selectedLanguage: .constant("en"),
                languages: Language.defaultLanguages,
                title: "Speak in",
                isSource: true
            )
            
            ModernLanguageSelector(
                selectedLanguage: .constant("es"),
                languages: Language.defaultLanguages,
                title: "Translate to",
                isSource: false
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif