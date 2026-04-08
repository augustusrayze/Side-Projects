import SwiftUI

struct ParchmentBackground: View {
    var body: some View {
        Color.parchment
            .overlay(Color.white.opacity(0.03))
            .ignoresSafeArea()
    }
}

struct ParchmentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            ParchmentBackground()
            content
        }
    }
}

extension View {
    func parchmentBackground() -> some View {
        modifier(ParchmentBackgroundModifier())
    }
}
