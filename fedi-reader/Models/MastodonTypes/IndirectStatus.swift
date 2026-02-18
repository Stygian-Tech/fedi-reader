import Foundation

final class IndirectStatus: Codable, Hashable, @unchecked Sendable {
    let value: Status
    
    init(_ value: Status) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Status.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value.id)
    }
    
    static func == (lhs: IndirectStatus, rhs: IndirectStatus) -> Bool {
        lhs.value.id == rhs.value.id
    }
}

// MARK: - Visibility


