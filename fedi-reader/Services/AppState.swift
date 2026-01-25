//
//  AppState.swift
//  fedi-reader
//
//  Global app state container using @Observable
//

import Foundation
import SwiftData

@Observable
@MainActor
final class AppState {
    // Services
    let client: MastodonClient
    let authService: AuthService
    
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
        self.client = MastodonClient()
        self.authService = AuthService(client: client)
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
        self.error = error
        
        // Show alert for user-facing errors
        if let fediError = error as? FediReaderError {
            let title: String
            let message: String
            
            if fediError == .unauthorized {
                title = "Authentication Required"
                message = "Your session has expired. Please log in again."
            } else {
                title = "Error"
                message = fediError.localizedDescription
            }
            
            presentedAlert = AlertItem(
                title: title,
                message: message
            )
        }
    }
    
    func clearError() {
        error = nil
        presentedAlert = nil
    }
    
    // MARK: - Navigation
    
    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func navigateToRoot() {
        navigationPath.removeAll()
    }
    
    func present(sheet: SheetDestination) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
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
