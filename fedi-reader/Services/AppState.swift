//
//  AppState.swift
//  fedi-reader
//
//  Global app state container using @Observable
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class AppState {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "AppState")
    
    // Services
    let client: MastodonClient
    let authService: AuthService
    let emojiService: EmojiService
    
    // Current state
    var isLoading = false
    var error: Error?
    var selectedTab: AppTab = .links
    
    // List and filter state
    var selectedListId: String? = nil  // nil = Home timeline
    var isUserFilterOpen = false
    var selectedUserFilter: String? = nil  // Account ID to filter by
    
    // Navigation state
    var navigationPath: [NavigationDestination] = []
    var presentedSheet: SheetDestination?
    var presentedAlert: AlertItem?
    
    init() {
        Self.logger.info("Initializing AppState")
        self.client = MastodonClient()
        self.authService = AuthService(client: client)
        self.emojiService = EmojiService(client: client)
    }
    
    // MARK: - Account Helpers
    
    var currentAccount: Account? {
        authService.currentAccount
    }
    
    var hasAccount: Bool {
        currentAccount != nil
    }
    
    func getAccessToken() async -> String? {
        guard let account = currentAccount else { return nil }
        return await authService.getAccessToken(for: account)
    }
    
    func getCurrentInstance() -> String? {
        currentAccount?.instance
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        Self.logger.error("Handling error: \(error.localizedDescription)")
        self.error = error
        
        // Show alert for user-facing errors
        if let fediError = error as? FediReaderError {
            let title: String
            let message: String
            
            if fediError == .unauthorized {
                title = "Authentication Required"
                message = "Your session has expired. Please log in again."
                Self.logger.notice("Unauthorized error - session expired")
            } else {
                title = "Error"
                message = fediError.localizedDescription
            }
            
            presentedAlert = AlertItem(
                title: title,
                message: message
            )
            Self.logger.info("Presented error alert: \(title, privacy: .public)")
        }
    }
    
    func clearError() {
        Self.logger.debug("Clearing error state")
        error = nil
        presentedAlert = nil
    }
    
    // MARK: - Navigation
    
    func navigate(to destination: NavigationDestination) {
        Self.logger.info("Navigating to: \(String(describing: destination), privacy: .public)")
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            let previous = navigationPath.last
            navigationPath.removeLast()
            Self.logger.info("Navigating back from: \(String(describing: previous), privacy: .public)")
        } else {
            Self.logger.debug("Navigate back called but navigation path is empty")
        }
    }
    
    func navigateToRoot() {
        let count = navigationPath.count
        navigationPath.removeAll()
        Self.logger.info("Navigating to root, cleared \(count) destinations")
    }
    
    func present(sheet: SheetDestination) {
        Self.logger.info("Presenting sheet: \(sheet.id, privacy: .public)")
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        if let sheet = presentedSheet {
            Self.logger.info("Dismissing sheet: \(sheet.id, privacy: .public)")
        }
        presentedSheet = nil
    }
}

// MARK: - App Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case links
    case explore
    case mentions
    case profile
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .links: return "Home"
        case .explore: return "Explore"
        case .mentions: return "Mentions"
        case .profile: return "Profile"
        }
    }
    
    var systemImage: String {
        switch self {
        case .links: return "house"
        case .explore: return "globe"
        case .mentions: return "at"
        case .profile: return "person"
        }
    }
}

// MARK: - Navigation Destinations

enum NavigationDestination: Hashable {
    case status(Status)
    case profile(MastodonAccount)
    case article(url: URL, status: Status)
    case thread(statusId: String)
    case hashtag(String)
    case settings
    case accountSettings
    case readLaterSettings
    case accountPosts(accountId: String, account: MastodonAccount)
    case accountFollowing(accountId: String, account: MastodonAccount)
    case accountFollowers(accountId: String, account: MastodonAccount)
}

// MARK: - Sheet Destinations

enum SheetDestination: Identifiable {
    case login
    case compose(replyTo: Status? = nil, quote: Status? = nil)
    case newMessage
    case readLaterLogin(ReadLaterServiceType)
    case shareSheet(url: URL)
    case accountSwitcher
    
    var id: String {
        switch self {
        case .login: return "login"
        case .compose: return "compose"
        case .newMessage: return "newMessage"
        case .readLaterLogin(let type): return "readLater-\(type.rawValue)"
        case .shareSheet: return "share"
        case .accountSwitcher: return "accountSwitcher"
        }
    }
}

// MARK: - Alert Item

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var primaryButton: AlertButton?
    var secondaryButton: AlertButton?
    
    struct AlertButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void
        
        enum ButtonRole {
            case cancel
            case destructive
        }
    }
}
