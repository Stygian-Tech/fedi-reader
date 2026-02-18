import SwiftUI

struct LiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(cornerRadius: CGFloat = Constants.UI.cardCornerRadius, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Tag


