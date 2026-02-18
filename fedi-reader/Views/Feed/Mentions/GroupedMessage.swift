import SwiftUI
import os

struct GroupedMessage: Identifiable {
    let id: String
    let account: MastodonAccount
    let messages: [ChatMessage]
    let isSent: Bool
    
    init(account: MastodonAccount, messages: [ChatMessage], isSent: Bool = false) {
        self.id = "\(account.id)-\(messages.first?.id ?? UUID().uuidString)"
        self.account = account
        self.messages = messages
        self.isSent = isSent
    }
}

// MARK: - Chat Message Group


