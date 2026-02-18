import SwiftUI

struct ProfileLinksGridView: View {
    let fields: [Field]

    @State private var containerWidth: CGFloat = 0

    var body: some View {
        let metrics = ProfileLinksGridLayout.metrics(containerWidth: containerWidth)

        LazyVGrid(
            columns: ProfileLinksGridLayout.gridItems(columnCount: metrics.columns),
            alignment: .leading,
            spacing: ProfileLinksGridLayout.interItemSpacing
        ) {
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                FieldCardView(field: field)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ProfileLinksGridLayout.horizontalPadding)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(key: ProfileLinksGridWidthPreferenceKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(ProfileLinksGridWidthPreferenceKey.self) { width in
            containerWidth = width
        }
    }
}


private struct ProfileLinksGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

