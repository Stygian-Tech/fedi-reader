//
//  WindowBackgroundColor.swift
//  fedi-reader
//
//  Sets the native window background to pure black (#000000) in dark mode
//  so Liquid Glass and other translucent layers sample correctly in windowed mode.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension View {
    /// Ensures the native window uses pure black (#000000) in dark mode and pure white in light mode,
    /// fixing gray backgrounds in windowed/split-view mode on macOS and iPadOS.
    func windowBackgroundColor(colorScheme: ColorScheme) -> some View {
        modifier(WindowBackgroundColorModifier(colorScheme: colorScheme))
    }
}

private struct WindowBackgroundColorModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .background {
                #if os(macOS)
                WindowBackgroundAccessor(colorScheme: colorScheme)
                #endif
            }
            .onAppear {
                #if os(iOS)
                applyWindowBackground()
                #endif
            }
            .onChange(of: colorScheme) { _, _ in
                #if os(iOS)
                applyWindowBackground()
                #endif
            }
    }

    #if os(iOS)
    private func applyWindowBackground() {
        let color: UIColor = colorScheme == .dark
            ? UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            : UIColor(white: 1, alpha: 1)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.backgroundColor = color
            }
        }
    }
    #endif
}

#if os(macOS)
private final class WindowBackgroundHostView: NSView {
    var colorScheme: ColorScheme = .dark
    var applyBackground: ((NSWindow, ColorScheme) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyIfNeeded()
    }

    func applyIfNeeded() {
        guard let window else { return }
        applyBackground?(window, colorScheme)
    }

    func setColorScheme(_ scheme: ColorScheme) {
        guard colorScheme != scheme else { return }
        colorScheme = scheme
        applyIfNeeded()
    }
}

private struct WindowBackgroundAccessor: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> WindowBackgroundHostView {
        let view = WindowBackgroundHostView()
        view.applyBackground = { window, scheme in
            window.backgroundColor = scheme == .dark
                ? NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1)
                : NSColor.white
        }
        return view
    }

    func updateNSView(_ nsView: WindowBackgroundHostView, context: Context) {
        nsView.setColorScheme(colorScheme)
    }
}
#endif
