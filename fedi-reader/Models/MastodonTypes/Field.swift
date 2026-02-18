import Foundation

struct Field: Codable, Hashable, Sendable {
    let name: String
    let value: String
    let verifiedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case name, value
        case verifiedAt = "verified_at"
    }

    init(name: String, value: String, verifiedAt: Date?) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)

        if let decodedDate = try? container.decode(Date.self, forKey: .verifiedAt) {
            verifiedAt = decodedDate
            return
        }

        guard let decodedDateString = try? container.decode(String.self, forKey: .verifiedAt),
              !decodedDateString.isEmpty else {
            verifiedAt = nil
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: decodedDateString) {
            verifiedAt = parsed
            return
        }

        formatter.formatOptions = [.withInternetDateTime]
        verifiedAt = formatter.date(from: decodedDateString)
    }
}

// MARK: - Media Attachment


