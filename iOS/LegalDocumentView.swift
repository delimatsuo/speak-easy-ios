import SwiftUI

struct LegalDocumentView: View {
    let resourceName: String
    let title: String
    @State private var content: AttributedString = ""
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
    
    private func load() {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let md = String(data: data, encoding: .utf8),
           let attributed = try? AttributedString(markdown: md) {
            content = attributed
        } else {
            content = AttributedString("Document not available.")
        }
    }
}


