import Foundation

struct AccountSource: Codable, Hashable, Sendable {
    let note: String?
    let fields: [Field]?

    init(note: String?, fields: [Field]?) {
        self.note = note
        self.fields = fields
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        fields = try container.decodeIfPresent([Field].self, forKey: .fields)
    }
}

// MARK: - Field (Profile fields)
