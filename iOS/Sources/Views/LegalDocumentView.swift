import SwiftUI

struct LegalDocumentView: View {
    let resourceName: String
    let title: String
    @State private var content: AttributedString = ""
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading document...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(content)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear(perform: load)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
    
    private func load() {
        isLoading = true
        
        // Try multiple possible locations for the legal documents
        let possiblePaths = [
            Bundle.main.url(forResource: resourceName, withExtension: "md"),
            Bundle.main.url(forResource: resourceName, withExtension: "md", subdirectory: "Legal"),
            Bundle.main.url(forResource: resourceName, withExtension: "md", subdirectory: "Resources/Legal")
        ]
        
        for url in possiblePaths {
            if let url = url,
               let data = try? Data(contentsOf: url),
               let md = String(data: data, encoding: .utf8) {
                
                // Use plain text directly since documents are now formatted as plain text
                content = AttributedString(md)
                isLoading = false
                return
            }
        }
        
        // If no document found, show error message
        content = AttributedString("Document not available. Please contact support at contact@electus.dev")
        isLoading = false
    }
}


