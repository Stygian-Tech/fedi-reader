//
//  TrendingLinkRow.swift
//  fedi-reader
//
//  Row view for a trending link in Explore.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TrendingLinkRow: View {
    let link: TrendingLink
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager

    var body: some View {
        Button {
            if let url = link.linkURL {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let imageURL = link.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                    }
                    .frame(width: 100, height: 100)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "link")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(link.title)
                        .font(.roundedHeadline)
                        .lineLimit(2)

                    if !link.description.isEmpty {
                        Text(link.description)
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        if let provider = link.providerName {
                            Text(provider)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }

                        if let author = link.authorName {
                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text(author)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.trailing, 12)

                Spacer()
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url = link.linkURL {
                Link(destination: url) {
                    Label("Open in Browser", systemImage: "safari")
                }

                ShareLink(item: url) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }

                Button {
                    #if os(iOS)
                    UIPasteboard.general.url = url
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .URL)
                    #endif
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }

                if readLaterManager.hasConfiguredServices {
                    Divider()

                    if let primary = readLaterManager.primaryService, let serviceType = primary.service {
                        Button {
                            Task {
                                try? await readLaterManager.save(
                                    url: url,
                                    title: link.title,
                                    to: serviceType
                                )
                            }
                        } label: {
                            Label("Save to \(serviceType.displayName)", systemImage: "bookmark")
                        }
                    }
                }
            }
        }
    }
}
