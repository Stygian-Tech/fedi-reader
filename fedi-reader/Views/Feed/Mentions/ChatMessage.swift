import SwiftUI
import os

struct ChatMessage: Identifiable {
    let id: String
    let notification: MastodonNotification?
    let status: Status?
    let isSent: Bool // true if this is a sent message (from current user)
    let createdAt: Date
    
    init(notification: MastodonNotification) {
        self.id = notification.id
        self.notification = notification
        self.status = notification.status
        self.isSent = false
        self.createdAt = notification.createdAt
    }
    
    init(status: Status, isSent: Bool = true) {
        self.id = status.id
        self.notification = nil
        self.status = status
        self.isSent = isSent
        self.createdAt = status.createdAt
    }
}

// MARK: - Conversations List View


