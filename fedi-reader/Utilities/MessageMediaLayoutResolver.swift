//
//  MessageMediaLayoutResolver.swift
//  fedi-reader
//
//  Provides aspect-aware chat media sizing so DM attachments stay readable
//  without collapsing into extreme letterboxed shapes.
//

import CoreGraphics
import Foundation

enum MessageMediaLayoutResolver {
    nonisolated static func size(for attachment: MediaAttachment) -> CGSize {
        let maxWidth: CGFloat = 260
        let maxHeight: CGFloat = 240
        let minWidth: CGFloat = 140
        let minHeight: CGFloat = 120
        let aspectRatio = clampedAspectRatio(for: attachment)

        if aspectRatio >= 1 {
            let width = maxWidth
            let height = clamped(width / aspectRatio, min: minHeight, max: maxHeight)
            return CGSize(width: width, height: height)
        }

        let height = maxHeight
        let width = clamped(height * aspectRatio, min: minWidth, max: maxWidth)
        return CGSize(width: width, height: height)
    }

    nonisolated static func clampedAspectRatio(for attachment: MediaAttachment) -> CGFloat {
        let minimumAspectRatio: CGFloat = 0.65
        let maximumAspectRatio: CGFloat = 1.8
        let rawAspectRatio = attachment.meta?.original?.aspect
            ?? attachment.meta?.small?.aspect
            ?? aspectRatio(
                width: attachment.meta?.original?.width ?? attachment.meta?.small?.width,
                height: attachment.meta?.original?.height ?? attachment.meta?.small?.height
            )
            ?? 1

        return clamped(CGFloat(rawAspectRatio), min: minimumAspectRatio, max: maximumAspectRatio)
    }

    private nonisolated static func aspectRatio(width: Int?, height: Int?) -> Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }

    private nonisolated static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
