//
//  ProfileLinksLayoutTests.swift
//  fedi-readerTests
//
//  Tests for responsive profile links grid layout math.
//

import Testing
import CoreGraphics
@testable import fedi_reader

@Suite("Profile Links Layout Tests")
struct ProfileLinksLayoutTests {
    @Test("Very narrow width uses one column")
    func veryNarrowWidthUsesOneColumn() {
        let metrics = ProfileLinksGridLayout.metrics(containerWidth: 200)
        #expect(metrics.columns == 1)
    }

    @Test("Phone width uses adaptive two-column layout with equal card width")
    func phoneWidthUsesTwoColumns() {
        let containerWidth: CGFloat = 390
        let metrics = ProfileLinksGridLayout.metrics(containerWidth: containerWidth)

        #expect(metrics.columns == 2)

        let usableWidth = max(0, containerWidth - (ProfileLinksGridLayout.horizontalPadding * 2))
        let expectedWidth = (usableWidth - ProfileLinksGridLayout.interItemSpacing) / 2
        #expect(abs(metrics.itemWidth - expectedWidth) < 0.001)
    }

    @Test("Tablet width uses three or more columns")
    func tabletWidthUsesThreeOrMoreColumns() {
        let containerWidth: CGFloat = 1024
        let metrics = ProfileLinksGridLayout.metrics(containerWidth: containerWidth)

        #expect(metrics.columns >= 3)

        let usableWidth = max(0, containerWidth - (ProfileLinksGridLayout.horizontalPadding * 2))
        let totalSpacing = ProfileLinksGridLayout.interItemSpacing * CGFloat(max(0, metrics.columns - 1))
        let totalContentWidth = (metrics.itemWidth * CGFloat(metrics.columns)) + totalSpacing
        #expect(abs(totalContentWidth - usableWidth) < 0.001)
    }

    @Test("Column count never drops below one")
    func columnCountNeverDropsBelowOne() {
        let widths: [CGFloat] = [-10, 0, 8]

        for width in widths {
            let metrics = ProfileLinksGridLayout.metrics(containerWidth: width)
            #expect(metrics.columns >= 1)
        }
    }
}
