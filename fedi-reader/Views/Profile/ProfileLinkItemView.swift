//
//  ProfileLinkItemView.swift
//  fedi-reader
//
//  Shared profile link presentation used by both card and list variants.
//

import SwiftUI

struct ProfileLinkItemView: View {
    enum Variant: Equatable {
        case card
        case listRow

        var cornerRadius: CGFloat {
            switch self {
            case .card:
                return 12
            case .listRow:
                return 12
            }
        }

        var contentInsets: EdgeInsets {
            switch self {
            case .card:
                return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            case .listRow:
                return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            }
        }

        var showsLeadingIcon: Bool {
            switch self {
            case .card:
                return true
            case .listRow:
                return false
            }
        }

        var titleFont: Font {
            switch self {
            case .card:
                return .roundedCaption.bold()
            case .listRow:
                return .roundedCaption
            }
        }

        var valueLineLimit: Int {
            switch self {
            case .card:
                return 2
            case .listRow:
                return 1
            }
        }

        var minimumHeight: CGFloat? {
            switch self {
            case .card:
                return 72
            case .listRow:
                return nil
            }
        }
    }

    enum ContainerPosition {
        case standalone
        case single
        case top
        case middle
        case bottom
    }

    let field: Field
    let destinationURL: URL?
    let variant: Variant
    let containerPosition: ContainerPosition

    init(
        field: Field,
        destinationURL: URL?,
        variant: Variant,
        containerPosition: ContainerPosition = .standalone
    ) {
        self.field = field
        self.destinationURL = destinationURL
        self.variant = variant
        self.containerPosition = containerPosition
    }

    @AppStorage("themeColor") private var themeColorName = "blue"

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    private var isVerified: Bool {
        field.verifiedAt != nil
    }

    private var valueText: String {
        field.decodedValue.htmlStripped
    }

    private var titleColor: Color {
        isVerified ? themeColor : .secondary
    }

    private var leadingIconColor: Color {
        if isVerified {
            return themeColor
        }
        return destinationURL == nil ? Color.secondary.opacity(0.55) : .secondary
    }

    private var trailingIconColor: Color {
        isVerified ? themeColor.opacity(0.9) : Color.secondary.opacity(0.55)
    }

    var body: some View {
        HStack(spacing: 12) {
            if variant.showsLeadingIcon {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(leadingIconColor)
                    .shadow(color: isVerified ? themeColor.opacity(0.25) : .clear, radius: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isVerified {
                    ProfileLinkVerificationBadge(themeColor: themeColor)
                }

                Text(field.decodedName)
                    .font(variant.titleFont)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .layoutPriority(1)

                Text(valueText)
                    .font(.roundedSubheadline)
                    .foregroundStyle(destinationURL == nil ? .secondary : .primary)
                    .lineLimit(variant.valueLineLimit)
                    .multilineTextAlignment(.leading)
                    .truncationMode(variant == .card ? .tail : .middle)
            }

            Spacer(minLength: 8)

            Image(systemName: destinationURL == nil ? "link.slash" : "arrow.up.right.square")
                .font(.roundedCaption)
                .foregroundStyle(trailingIconColor)
        }
        .contentShape(Rectangle())
        .padding(variant.contentInsets)
        .frame(
            maxWidth: .infinity,
            minHeight: variant.minimumHeight,
            alignment: .leading
        )
        .modifier(
            ProfileLinkChromeModifier(
                variant: variant,
                containerPosition: containerPosition,
                isVerified: isVerified,
                themeColor: themeColor
            )
        )
    }
}

private struct ProfileLinkVerificationBadge: View {
    let themeColor: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.seal.fill")
            Text("Verified")
        }
        .font(.roundedCaption2.bold())
        .foregroundStyle(themeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(themeColor.opacity(0.14))
        }
        .overlay {
            Capsule()
                .stroke(themeColor.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: themeColor.opacity(0.22), radius: 8)
    }
}

private struct ProfileLinkChromeModifier: ViewModifier {
    let variant: ProfileLinkItemView.Variant
    let containerPosition: ProfileLinkItemView.ContainerPosition
    let isVerified: Bool
    let themeColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        switch variant {
        case .card:
            content
                .background {
                    if isVerified {
                        verifiedBackground
                    }
                }
                .glassEffect(.regular, in: chromeShape)
                .overlay {
                    if isVerified {
                        verifiedOutline
                    }
                }
                .shadow(color: isVerified ? themeColor.opacity(0.26) : .clear, radius: 18)
                .shadow(color: isVerified ? themeColor.opacity(0.14) : .clear, radius: 30)
        case .listRow:
            content
                .background {
                    if isVerified {
                        verifiedBackground
                    }
                }
                .overlay {
                    if isVerified {
                        verifiedOutline
                    }
                }
                .shadow(color: isVerified ? themeColor.opacity(0.20) : .clear, radius: 12)
                .shadow(color: isVerified ? themeColor.opacity(0.12) : .clear, radius: 22)
        }
    }

    private var verifiedBackground: some View {
        chromeShape
            .fill(themeColor.opacity(0.14))
    }

    private var verifiedOutline: some View {
        chromeShape
            .stroke(themeColor.opacity(0.30), lineWidth: 1)
    }

    private var chromeShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: cornerRadii,
            style: .continuous
        )
    }

    private var cornerRadii: RectangleCornerRadii {
        let radius = variant.cornerRadius

        switch variant {
        case .card:
            return .init(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            )
        case .listRow:
            switch containerPosition {
            case .standalone, .single:
                return .init(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                )
            case .top:
                return .init(
                    topLeading: radius,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: radius
                )
            case .middle:
                return .init(
                    topLeading: 0,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: 0
                )
            case .bottom:
                return .init(
                    topLeading: 0,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: 0
                )
            }
        }
    }
}
