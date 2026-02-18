import Foundation

enum NotificationType: String, Codable, Sendable {
    case mention
    case status
    case reblog
    case follow
    case followRequest = "follow_request"
    case favourite
    case poll
    case update
    case adminSignUp = "admin.sign_up"
    case adminReport = "admin.report"
}

// MARK: - Conversation


