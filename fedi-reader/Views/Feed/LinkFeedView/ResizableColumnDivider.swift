//
//  ResizableColumnDivider.swift
//  fedi-reader
//
//  Draggable divider for resizable column layouts.
//

import SwiftUI

struct ResizableColumnDivider: View {
    @Binding var width: Double
    let minValue: CGFloat
    let maxValue: CGFloat
    var onDragEnd: (() -> Void)? = nil

    @State private var gestureStartWidth: Double?

    private let dividerWidth: CGFloat = 4

    private var safeMinValue: Double {
        let candidate = Double(minValue)
        guard candidate.isFinite else { return 0 }
        return candidate
    }

    private var safeMaxValue: Double {
        let candidate = Double(maxValue)
        guard candidate.isFinite else { return safeMinValue }
        return max(candidate, safeMinValue)
    }

    private var safeCurrentWidth: Double {
        width.isFinite ? width : safeMinValue
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: dividerWidth)
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 2)
                    .padding(.horizontal, (dividerWidth - 2) / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let start = gestureStartWidth ?? safeCurrentWidth
                        if gestureStartWidth == nil {
                            gestureStartWidth = start
                        }
                        let translation = value.translation.width.isFinite ? Double(value.translation.width) : 0
                        let newValue = start + translation
                        let clamped = newValue.clamped(to: safeMinValue...safeMaxValue)
                        var t = Transaction()
                        t.animation = nil
                        withTransaction(t) { width = clamped }
                    }
                    .onEnded { _ in
                        gestureStartWidth = nil
                        onDragEnd?()
                    }
            )
            .accessibilityLabel("Resize column")
            .accessibilityAddTraits(.isButton)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
