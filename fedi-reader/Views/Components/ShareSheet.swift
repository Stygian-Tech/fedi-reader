//
//  ShareSheet.swift
//  fedi-reader
//
//  Share link sheet view.
//

import SwiftUI

struct ShareSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Share")
                .font(.headline)

            ShareLink(item: url) {
                Label("Share Link", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}
