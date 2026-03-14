//
//  FieldCardView.swift
//  fedi-reader
//
//  Profile field card (link) view.
//

import SwiftUI

struct FieldCardView: View {
    let field: Field

    @Environment(\.openURL) private var openURL

    var body: some View {
        let linkURL = field.profileDestinationURL

        Button {
            if let linkURL {
                openURL(linkURL)
            }
        } label: {
            ProfileLinkItemView(field: field, destinationURL: linkURL, variant: .card)
        }
        .buttonStyle(.plain)
        .disabled(linkURL == nil)
    }
}
