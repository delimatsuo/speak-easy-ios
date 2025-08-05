import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    
    var body: some View {
        NavigationView {
            TranslationView()
                .environmentObject(viewModel)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    ContentView()
}