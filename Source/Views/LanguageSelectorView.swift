import SwiftUI

struct LanguageSelectorView: View {
    let selectedLanguage: Language
    let onLanguageSelected: (Language) -> Void
    
    @State private var searchText = ""
    @State private var favoriteLanguages: Set<String> = []
    @State private var recentLanguages: [Language] = []
    @Environment(\.dismiss) private var dismiss
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.supportedLanguages
        } else {
            return Language.supportedLanguages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText) ||
                language.code.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var favoritesList: [Language] {
        Language.supportedLanguages.filter { favoriteLanguages.contains($0.code) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                List {
                    if !favoritesList.isEmpty {
                        favoritesSection
                    }
                    
                    if !recentLanguages.isEmpty {
                        recentSection
                    }
                    
                    allLanguagesSection
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadUserPreferences()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search languages...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var favoritesSection: some View {
        Section {
            ForEach(favoritesList) { language in
                LanguageRow(
                    language: language,
                    isSelected: language.code == selectedLanguage.code,
                    isFavorite: favoriteLanguages.contains(language.code),
                    onTap: {
                        selectLanguage(language)
                    },
                    onFavoriteToggle: {
                        toggleFavorite(language)
                    }
                )
            }
        } header: {
            Label("Favorites", systemImage: "star.fill")
                .foregroundColor(.yellow)
        }
    }
    
    private var recentSection: some View {
        Section {
            ForEach(recentLanguages.prefix(5)) { language in
                LanguageRow(
                    language: language,
                    isSelected: language.code == selectedLanguage.code,
                    isFavorite: favoriteLanguages.contains(language.code),
                    onTap: {
                        selectLanguage(language)
                    },
                    onFavoriteToggle: {
                        toggleFavorite(language)
                    }
                )
            }
        } header: {
            Label("Recent", systemImage: "clock")
                .foregroundColor(.blue)
        }
    }
    
    private var allLanguagesSection: some View {
        Section {
            ForEach(filteredLanguages) { language in
                LanguageRow(
                    language: language,
                    isSelected: language.code == selectedLanguage.code,
                    isFavorite: favoriteLanguages.contains(language.code),
                    onTap: {
                        selectLanguage(language)
                    },
                    onFavoriteToggle: {
                        toggleFavorite(language)
                    }
                )
            }
        } header: {
            Label("All Languages", systemImage: "globe")
                .foregroundColor(.green)
        }
    }
    
    private func selectLanguage(_ language: Language) {
        addToRecent(language)
        onLanguageSelected(language)
        HapticManager.shared.selectionChanged()
    }
    
    private func toggleFavorite(_ language: Language) {
        if favoriteLanguages.contains(language.code) {
            favoriteLanguages.remove(language.code)
        } else {
            favoriteLanguages.insert(language.code)
        }
        saveFavorites()
        HapticManager.shared.lightImpact()
    }
    
    private func addToRecent(_ language: Language) {
        recentLanguages.removeAll { $0.code == language.code }
        recentLanguages.insert(language, at: 0)
        if recentLanguages.count > 5 {
            recentLanguages.removeLast()
        }
        saveRecent()
    }
    
    private func loadUserPreferences() {
        if let favoriteCodes = UserDefaults.standard.array(forKey: "favoriteLanguages") as? [String] {
            favoriteLanguages = Set(favoriteCodes)
        }
        
        if let recentCodes = UserDefaults.standard.array(forKey: "recentLanguages") as? [String] {
            recentLanguages = recentCodes.compactMap { code in
                Language.supportedLanguages.first { $0.code == code }
            }
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteLanguages), forKey: "favoriteLanguages")
    }
    
    private func saveRecent() {
        UserDefaults.standard.set(recentLanguages.map(\.code), forKey: "recentLanguages")
    }
}

struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(language.flag)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(language.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(language.nativeName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if language.isOfflineAvailable {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Button(action: onFavoriteToggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .gray)
                    .font(.body)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    LanguageSelectorView(
        selectedLanguage: Language.defaultSource,
        onLanguageSelected: { _ in }
    )
}