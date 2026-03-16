import SwiftUI
import os

struct GroupedMessage: Identifiable {
    let id: String
    let account: MastodonAccount
    let messages: [ChatMessage]
    let isSent: Bool
    let isGroupChat: Bool
    
    init(
        account: MastodonAccount,
        messages: [ChatMessage],
        isSent: Bool = false,
        isGroupChat: Bool = false
    ) {
        self.id = "\(account.id)-\(messages.first?.id ?? UUID().uuidString)"
        self.account = account
        self.messages = messages
        self.isSent = isSent
        self.isGroupChat = isGroupChat
    }
}

// MARK: - Chat Message Group

