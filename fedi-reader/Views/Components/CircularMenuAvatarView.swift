//
//  CircularMenuAvatarView.swift
//  fedi-reader
//
//  Avatar pre-rendered as circular image for use in SwiftUI Menu, which ignores
//  clipShape/mask modifiers on child views. Must apply masking before display.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

struct CircularMenuAvatarView: View {
    let url: URL?
    let size: CGFloat
    @State private var circularImage: PlatformImage?

    var body: some View {
        Group {
            if let circularImage {
                Image(platformImage: circularImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(.tertiary)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .task(id: url?.absoluteString) {
            guard let url else { return }
            circularImage = await loadCircularImage(from: url, size: size)
        }
    }

    private func loadCircularImage(from url: URL, size: CGFloat) async -> PlatformImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            #if os(iOS)
            guard let uiImage = UIImage(data: data) else { return nil }
            return uiImage.circularImage(size: size)
            #elseif os(macOS)
            guard let nsImage = NSImage(data: data) else { return nil }
            return nsImage.circularImage(size: size)
            #endif
        } catch {
            return nil
        }
    }
}

// MARK: - Platform Image Bridge

#if os(iOS)
typealias PlatformImage = UIImage

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif

#if os(macOS)
typealias PlatformImage = NSImage

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#endif

// MARK: - UIImage Circular Mask (iOS)

#if os(iOS)
private extension UIImage {
    func circularImage(size: CGFloat) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            UIBezierPath(ovalIn: rect).addClip()
            let imageSize = self.size
            let scale = max(size / imageSize.width, size / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let drawRect = CGRect(
                x: (size - scaledSize.width) / 2,
                y: (size - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            draw(in: drawRect)
        }
    }
}
#endif

// MARK: - NSImage Circular Mask (macOS)

#if os(macOS)
private extension NSImage {
    func circularImage(size: CGFloat) -> NSImage? {
        let composedImage = NSImage(size: NSSize(width: size, height: size))
        composedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSBezierPath(ovalIn: rect).addClip()

        let scale = max(size / self.size.width, size / self.size.height)
        let scaledSize = NSSize(width: self.size.width * scale, height: self.size.height * scale)
        let drawRect = NSRect(
            x: (size - scaledSize.width) / 2,
            y: (size - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        draw(in: drawRect, from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1)

        composedImage.unlockFocus()
        return composedImage
    }
}
#endif
