import SwiftUI
import os

struct TapbackView: View {
    let count: Int
    let isMine: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isMine ? "star.fill" : "star.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isMine ? .yellow : .secondary)
            
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - New Message View


