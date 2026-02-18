import Foundation

struct MediaMeta: Codable, Hashable, Sendable {
    let original: MediaDimensions?
    let small: MediaDimensions?
    let focus: MediaFocus?
}


