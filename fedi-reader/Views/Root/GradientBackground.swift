import SwiftUI

struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Adaptive base color
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color.accentColor.opacity(0.15),
                    Color.clear,
                    Color.accentColor.opacity(0.08)
                ] : [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

