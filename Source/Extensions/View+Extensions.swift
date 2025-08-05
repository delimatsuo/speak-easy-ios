import SwiftUI

extension View {
    func pressGesture(onPress: @escaping () -> Void) -> some View {
        self.onTapGesture {
            onPress()
        }
    }
}

extension View {
    @ViewBuilder
    func conditionalModifier<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}