import SwiftUI

struct LanguagePickerSheet: View {
    let languages: [Language]
    @Binding var selectedCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(languages) { lang in
                HStack {
                    Text(lang.flag)
                    Text(lang.name)
                    Spacer()
                    if lang.code == selectedCode {
                        Image(systemName: "checkmark").foregroundColor(.speakEasyPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCode = lang.code
                    dismiss()
                }
            }
            .navigationTitle("Choose language")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}


