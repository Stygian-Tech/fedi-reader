import Foundation
import SwiftData

@Model
final class CachedStatus {
    @Attribute(.unique) var id: String
    var accountId: String // Reference to the Account that fetched this
    var jsonData: Data // Serialized Status JSON
    var fetchedAt: Date
    var timelineType: String // "home", "mentions", "explore"
    var hasLinkCard: Bool
    var cardURL: String?
    var cardTitle: String?
    var cardImageURL: String?
    var authorAttribution: String? // Cached author name if found
    
    init(
        id: String,
        accountId: String,
        jsonData: Data,
        fetchedAt: Date = Date(),
        timelineType: String,
        hasLinkCard: Bool = false,
        cardURL: String? = nil,
        cardTitle: String? = nil,
        cardImageURL: String? = nil,
        authorAttribution: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.jsonData = jsonData
        self.fetchedAt = fetchedAt
        self.timelineType = timelineType
        self.hasLinkCard = hasLinkCard
        self.cardURL = cardURL
        self.cardTitle = cardTitle
        self.cardImageURL = cardImageURL
        self.authorAttribution = authorAttribution
    }
    
    @MainActor
    var status: Status? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Status.self, from: jsonData)
    }
    
    @MainActor
    static func from(status: Status, accountId: String, timelineType: String) -> CachedStatus? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(status) else {
            return nil
        }
        
        return CachedStatus(
            id: status.id,
            accountId: accountId,
            jsonData: jsonData,
            timelineType: timelineType,
            hasLinkCard: status.hasLinkCard,
            cardURL: status.card?.url,
            cardTitle: status.card?.title,
            cardImageURL: status.card?.image,
            authorAttribution: status.card?.authorName
        )
    }
}

// MARK: - Timeline Type

