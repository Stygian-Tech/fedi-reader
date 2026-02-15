//
//  Field+ProfileLink.swift
//  fedi-reader
//
//  Shared profile link parsing for profile field rows.
//

import Foundation

extension Field {
    var profileDestinationURL: URL? {
        if let extractedLink = value.extractedLinks.first {
            return extractedLink
        }

        let stripped = value.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix("http://") || stripped.hasPrefix("https://") else {
            return nil
        }
        return URL(string: stripped)
    }
}
