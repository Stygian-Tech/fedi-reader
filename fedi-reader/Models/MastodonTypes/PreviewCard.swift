import Foundation

struct PreviewCard: Codable, Hashable, Sendable {
    let url: String
    let title: String
    let description: String
    let type: CardType
    let authorName: String?
    let authorUrl: String?
    let providerName: String?
    let providerUrl: String?
    let html: String?
    let width: Int?
    let height: Int?
    let image: String?
    let blurhash: String?
    let embedUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, description, type, html, width, height, image, blurhash
        case authorName = "author_name"
        case authorUrl = "author_url"
        case providerName = "provider_name"
        case providerUrl = "provider_url"
        case embedUrl = "embed_url"
    }
    
    nonisolated var imageURL: URL? {
        guard let image else { return nil }
        return URL(string: image)
    }
    
    nonisolated var linkURL: URL? {
        URL(string: url)
    }
}


