//
//  LiquidGlassComponents.swift
//  fedi-reader
//
//  Reusable liquid glass (glassmorphism) components
//

import SwiftUI

// MARK: - Liquid Glass Card

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

struct LiquidGlassTag: View {
    let text: String
    let action: (() -> Void)?
    
    init(_ text: String, action: (() -> Void)? = nil) {
        self.text = text
        self.action = action
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 14) {
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }
}

// MARK: - Glass Effect Container Wrapper

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
