import SwiftUI

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .glassEffect(.clear, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.roundedHeadline)

                Text(description)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


