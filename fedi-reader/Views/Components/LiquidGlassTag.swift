import SwiftUI

struct LiquidGlassTag: View {
    let text: String
    let action: (() -> Void)?
    @AppStorage("themeColor") private var themeColorName = "blue"
    
    init(_ text: String, action: (() -> Void)? = nil) {
        self.text = text
        self.action = action
    }
    
    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }
    
    var body: some View {
        if let action = action {
            Button(action: action) {
                tagContent
            }
            .buttonStyle(.plain)
        } else {
            tagContent
        }
    }
    
    private var tagContent: some View {
        Text(text)
            .font(.roundedCaption)
            .foregroundStyle(themeColor)
            .shadow(color: themeColor.opacity(0.6), radius: 4, x: 0, y: 0)
            .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 0)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
    }
}

// MARK: - Liquid Glass Button Style


