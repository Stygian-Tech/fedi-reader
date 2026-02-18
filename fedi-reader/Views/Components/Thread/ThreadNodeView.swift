import SwiftUI

struct ThreadNodeView: View {
    let node: ThreadNode
    let depth: Int
    let isLastSibling: Bool
    @Environment(AppState.self) private var appState
    @State private var isExpanded = true
    @State private var showAllReplies = false
    
    private let indentPerLevel: CGFloat = 4
    private let connectorWidth: CGFloat = 1
    private let maxVisibleReplies = 4
    
    private var visibleChildren: [ThreadNode] {
        if node.children.count <= maxVisibleReplies || showAllReplies {
            return node.children
        } else {
            return Array(node.children.prefix(maxVisibleReplies))
        }
    }
    
    private var hasMoreReplies: Bool {
        node.children.count > maxVisibleReplies && !showAllReplies
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Thread connectors
                if depth > 0 {
                    threadConnectors
                }
                
                // Status content
                VStack(alignment: .leading, spacing: 0) {
                    CompactStatusRowView(status: node.status, depth: depth)
                    
                    // Children
                    if !node.children.isEmpty && isExpanded {
                        ForEach(Array(visibleChildren.enumerated()), id: \.element.id) { index, child in
                            ThreadNodeView(
                                node: child,
                                depth: depth + 1,
                                isLastSibling: index == visibleChildren.count - 1 && !hasMoreReplies
                            )
                        }
                        
                        // "See more" button
                        if hasMoreReplies {
                            Button {
                                withAnimation {
                                    showAllReplies = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("See \(node.children.count - maxVisibleReplies) more replies")
                                        .font(.roundedSubheadline)
                                        .foregroundStyle(.blue)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, depth > 0 ? 5 : 11)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, CGFloat(depth) * indentPerLevel)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var threadConnectors: some View {
        HStack(spacing: 0) {
            // Vertical line for depth levels
            ForEach(0..<depth, id: \.self) { level in
                if level == depth - 1 {
                    // Current level: show connector based on sibling position
                    VStack(spacing: 0) {
                        // Horizontal line to status
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 3, height: connectorWidth)
                        
                        // Vertical line if not last sibling
                        if !isLastSibling {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: connectorWidth)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: indentPerLevel)
                } else {
                    // Previous levels: show vertical line if not last sibling
                    VStack(spacing: 0) {
                        if !isLastSibling {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: connectorWidth)
                                .frame(maxHeight: .infinity)
                        } else {
                            Spacer()
                                .frame(width: connectorWidth)
                        }
                    }
                    .frame(width: indentPerLevel)
                }
            }
        }
        .frame(width: CGFloat(depth) * indentPerLevel)
    }
}

// MARK: - Thread View


