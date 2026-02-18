import SwiftUI

struct GlassEffectContainer<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        // GlassEffectContainer groups glass effects for shared background sampling
        // In iOS 26, this is handled automatically by SwiftUI when glass effects are in the same container
        content()
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    VStack(spacing: 20) {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(.roundedHeadline)
                Text("This is a liquid glass card with translucent background")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        
        HStack(spacing: 8) {
            LiquidGlassTag("semantic search")
            LiquidGlassTag("chat with notes")
            LiquidGlassTag("auto-tagging")
            LiquidGlassTag("encrypted")
        }
        
        Button("Liquid Glass Button") {
            // Action
        }
        .buttonStyle(.liquidGlass)
    }
    .padding()
    .background(Color.black)
}

