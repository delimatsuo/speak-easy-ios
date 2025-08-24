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
        
        // First, check all possible file extensions and paths
        let possibleExtensions = ["md", "txt"]
        let possiblePaths: [String?] = [
            // Try main bundle first
            Bundle.main.path(forResource: resourceName, ofType: "md"),
            Bundle.main.path(forResource: resourceName, ofType: "txt"),
            // Try with Legal subdirectory
            Bundle.main.path(forResource: resourceName, ofType: "md", inDirectory: "Legal"),
            Bundle.main.path(forResource: resourceName, ofType: "txt", inDirectory: "Legal"),
            // Try with Resources/Legal subdirectory
            Bundle.main.path(forResource: resourceName, ofType: "md", inDirectory: "Resources/Legal"),
            Bundle.main.path(forResource: resourceName, ofType: "txt", inDirectory: "Resources/Legal"),
        ]
        
        // Log available resources for debugging
        print("🔍 Looking for legal document: \(resourceName)")
        if let bundlePath = Bundle.main.resourcePath {
            print("📁 Bundle resource path: \(bundlePath)")
        }
        
        // Try all possible paths
        for path in possiblePaths {
            if let filePath = path,
               let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
               let documentText = String(data: data, encoding: .utf8) {
                
                print("✅ Found legal document at: \(filePath)")
                content = AttributedString(documentText)
                isLoading = false
                return
            }
        }
        
        // Additional fallback: try to find any file starting with the resource name
        if let bundlePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                for file in contents {
                    if file.hasPrefix(resourceName) && (file.hasSuffix(".md") || file.hasSuffix(".txt")) {
                        let fullPath = "\(bundlePath)/\(file)"
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                           let documentText = String(data: data, encoding: .utf8) {
                            print("✅ Found legal document via fallback: \(fullPath)")
                            content = AttributedString(documentText)
                            isLoading = false
                            return
                        }
                    }
                }
            } catch {
                print("❌ Error scanning bundle directory: \(error)")
            }
        }
        
        // If still no document found, provide fallback content based on document type
        let fallbackContent: String
        if resourceName.contains("TERMS") {
            fallbackContent = """
            Universal AI Translator - Terms of Use
            
            Thank you for using Universal AI Translator!
            
            This app provides AI-powered translation services with a focus on privacy and user experience.
            
            Key Points:
            • We don't store your conversations
            • Only minimal purchase and session metadata is kept
            • Free weekly translation credits are provided
            • Additional credits can be purchased as needed
            
            For the complete Terms of Use, please visit our website or contact us at contact@electus.dev
            
            By using this app, you agree to these terms and our Privacy Policy.
            """
        } else if resourceName.contains("PRIVACY") {
            fallbackContent = """
            Universal AI Translator - Privacy Policy
            
            Your Privacy Matters
            
            We are committed to protecting your privacy:
            
            • No conversation storage - your translations are not saved
            • Minimal data collection - only what's needed for the app to function
            • Purchase data is kept secure and only used for billing
            • No sharing of personal information with third parties
            • Data retention is limited to 12 months maximum
            
            For complete privacy details, please contact us at contact@electus.dev
            
            This privacy policy is effective as of the app installation date.
            """
        } else {
            fallbackContent = "Document not available. Please contact support at contact@electus.dev"
        }
        
        content = AttributedString(fallbackContent)
        print("⚠️ Using fallback content for \(resourceName)")
        isLoading = false
    }
}


