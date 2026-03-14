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
                        row(
                            field: field,
                            destinationURL: destinationURL,
                            containerPosition: containerPosition(for: index)
                        )
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

    private func row(
        field: Field,
        destinationURL: URL?,
        containerPosition: ProfileLinkItemView.ContainerPosition
    ) -> some View {
        ProfileLinkItemView(
            field: field,
            destinationURL: destinationURL,
            variant: .listRow,
            containerPosition: containerPosition
        )
    }

    private func containerPosition(for index: Int) -> ProfileLinkItemView.ContainerPosition {
        if fields.count == 1 {
            return .single
        }
        if index == 0 {
            return .top
        }
        if index == fields.count - 1 {
            return .bottom
        }
        return .middle
    }
}
