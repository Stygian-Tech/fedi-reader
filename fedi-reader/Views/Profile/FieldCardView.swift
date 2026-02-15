//
//  FieldCardView.swift
//  fedi-reader
//
//  Profile field card (link) view.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct FieldCardView: View {
    let field: Field

    var body: some View {
        let linkURL = destinationURL

        Button {
            if let linkURL {
                #if os(iOS)
                UIApplication.shared.open(linkURL)
                #elseif os(macOS)
                NSWorkspace.shared.open(linkURL)
                #endif
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(linkURL == nil ? .tertiary : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(field.name)
                            .font(.roundedCaption.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if field.verifiedAt != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.roundedCaption)
                        }
                    }

                    Text(field.value.htmlStripped)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: linkURL == nil ? "link.slash" : "arrow.up.right.square")
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(linkURL == nil)
    }

    private var destinationURL: URL? {
        guard let urlString = extractURL(from: field.value) else {
            return nil
        }
        return URL(string: urlString)
    }

    private func extractURL(from html: String) -> String? {
        let pattern = #"href=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let urlRange = Range(match.range(at: 1), in: html) {
                return String(html[urlRange])
            }
        }

        let stripped = html.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("http://") || stripped.hasPrefix("https://") {
            return stripped
        }

        return nil
    }
}
