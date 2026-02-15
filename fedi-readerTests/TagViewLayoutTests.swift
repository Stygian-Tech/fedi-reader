//
//  TagViewLayoutTests.swift
//  fedi-readerTests
//
//  Tests for TagView collapsed tag partitioning logic.
//

import CoreGraphics
import Testing
@testable import fedi_reader

@Suite("Tag View Layout Tests")
struct TagViewLayoutTests {
    @Test("Returns all tags when width is unavailable")
    func returnsAllTagsWhenWidthUnavailable() {
        let tags = ["swift", "ios", "fedi"]
        let partition = TagView.partitionTags(
            tags,
            availableWidth: 0,
            measuredTagSizes: [:]
        )

        #expect(partition.visible == tags)
        #expect(partition.hidden.isEmpty)
    }

    @Test("Reserves room for +N button in collapsed row")
    func reservesRoomForMoreButton() {
        let tags = ["swift", "ios", "fedi"]
        let sizes: [String: CGSize] = [
            "swift": CGSize(width: 50, height: 24),
            "ios": CGSize(width: 50, height: 24),
            "fedi": CGSize(width: 50, height: 24)
        ]

        let partition = TagView.partitionTags(
            tags,
            availableWidth: 120,
            measuredTagSizes: sizes
        )

        #expect(partition.visible == ["swift"])
        #expect(partition.hidden == ["ios", "fedi"])
    }

    @Test("Keeps first tag visible on extremely narrow widths")
    func keepsFirstTagVisibleOnNarrowWidths() {
        let tags = ["swift", "ios", "fedi"]
        let sizes: [String: CGSize] = [
            "swift": CGSize(width: 50, height: 24),
            "ios": CGSize(width: 50, height: 24),
            "fedi": CGSize(width: 50, height: 24)
        ]

        let partition = TagView.partitionTags(
            tags,
            availableWidth: 20,
            measuredTagSizes: sizes
        )

        #expect(partition.visible == ["swift"])
        #expect(partition.hidden == ["ios", "fedi"])
    }
}
