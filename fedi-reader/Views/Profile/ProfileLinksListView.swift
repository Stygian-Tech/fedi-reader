//
//  ProfileLinksListView.swift
//  fedi-reader
//
//  Profile links rendered in profile-tab row style.
//

import SwiftUI

struct ProfileLinksListView: View {
    let fields: [Field]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.roundedCaption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                    let destinationURL = field.profileDestinationURL

                    Button {
                        if let destinationURL {
                            openURL(destinationURL)
                        }
                    } label: {
                        row(field: field, destinationURL: destinationURL)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(destinationURL == nil)

                    if index < fields.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private func row(field: Field, destinationURL: URL?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(field.name)
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if field.verifiedAt != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.roundedCaption2)
                            .foregroundStyle(.green)
                    }
                }

                Text(field.value.htmlStripped)
                    .font(.roundedSubheadline)
                    .foregroundStyle(destinationURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Image(systemName: destinationURL == nil ? "link.slash" : "arrow.up.right.square")
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
