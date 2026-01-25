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
        Button {
            if let urlString = extractURL(from: field.value),
               let url = URL(string: urlString) {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if field.verifiedAt != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.roundedCaption)
                    }

                    Text(field.name)
                        .font(.roundedCaption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(field.value.htmlStripped)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 200)
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
