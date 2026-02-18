import Foundation

struct GroupedConversation: Identifiable {
    let id: String
    let participants: [MastodonAccount] // Other participants (excluding current user)
    let conversations: [MastodonConversation]
    let isGroupChat: Bool

    var lastStatus: Status? {
        conversations
            .compactMap { $0.lastStatus }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    var lastUpdated: Date {
        lastStatus?.createdAt ?? Date.distantPast
    }

    var unread: Bool {
        conversations.contains { $0.unread == true }
    }

    var displayName: String {
        if isGroupChat {
            let names = participants.prefix(3).map { $0.displayName }
            if participants.count > 3 {
                return names.joined(separator: ", ") + " +\(participants.count - 3)"
            }
            return names.joined(separator: ", ")
        } else {
            return participants.first?.displayName ?? "Unknown"
        }
    }

    var primaryAccount: MastodonAccount? {
        participants.first
    }
}


