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
            LinkCardContent(link: link)
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
