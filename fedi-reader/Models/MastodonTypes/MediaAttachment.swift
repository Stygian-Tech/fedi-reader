import Foundation

struct MediaAttachment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: MediaType
    let url: String
    let previewUrl: String?
    let remoteUrl: String?
    let description: String?
    let blurhash: String?
    let meta: MediaMeta?
    
    enum CodingKeys: String, CodingKey {
        case id, type, url, description, blurhash, meta
        case previewUrl = "preview_url"
        case remoteUrl = "remote_url"
    }
}


