import SwiftUI

struct ReplyThreadCard: View {
    let thread: ThreadNode
    @Environment(\.colorScheme) private var colorScheme
    private let cardShape = RoundedRectangle(
        cornerRadius: Constants.UI.cardCornerRadius,
        style: .continuous
    )

    private var nestedReplyCount: Int {
        max(thread.totalReplies - 1, 0)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.035)
            : Color.black.opacity(0.025)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if nestedReplyCount > 0 {
                HStack(spacing: 8) {
                    Label("\(nestedReplyCount) more in thread", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            ReplyThreadNodeDetailView(node: thread, depth: 0)
        }
        .padding(12)
        .background(cardShape.fill(cardFill))
        .overlay(
            cardShape
                .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(cardShape)
    }
}

private struct ReplyThreadNodeDetailView: View {
    let node: ThreadNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusDetailRowView(status: node.status, style: .embedded, replyThreadDepth: depth)

            if !node.children.isEmpty {
                ReplyThreadGroup(depth: depth) {
                    ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                        ReplyThreadChildView(
                            node: child,
                            depth: depth + 1,
                            isLastSibling: index == node.children.count - 1
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct ReplyThreadGroup<Content: View>: View {
    let depth: Int
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(depth: Int, @ViewBuilder content: () -> Content) {
        self.depth = depth
        self.content = content()
    }

    private var backgroundColor: Color {
        let baseOpacity = colorScheme == .dark ? 0.04 : 0.025
        let nestedAdjustment = depth == 0 ? baseOpacity : baseOpacity * 0.75
        return (colorScheme == .dark ? Color.white : Color.black).opacity(nestedAdjustment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ReplyThreadChildView: View {
    let node: ThreadNode
    let depth: Int
    let isLastSibling: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 5, height: 5)

                Text(TimeFormatter.relativeTimeString(from: node.status.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }

            ReplyThreadNodeDetailView(node: node, depth: depth)

            if !isLastSibling {
                Divider()
                    .padding(.top, 2)
            }
        }
    }
}
