import SwiftUI

struct ThreadConnector: View {
    let hasSiblingBelow: Bool
    let depth: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Vertical line
            if hasSiblingBelow {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 2)
            } else {
                Spacer()
                    .frame(width: 2)
            }
        }
        .frame(width: 20)
    }
}

