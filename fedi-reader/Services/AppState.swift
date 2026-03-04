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
    static let homeFeedID = "home"
    static let defaultListIdStorageKey = "defaultListId"
    private static let listDisplayPreferencesStorageKeyPrefix = "listDisplayPreferences."
    private static let listDisplayPreferencesEncoder = JSONEncoder()
    private static let listDisplayPreferencesDecoder = JSONDecoder()
    
    // Services
    let client: MastodonClient
    let authService: AuthService
    let emojiService: EmojiService
    
    // Current state
    var isLoading = false
    var error: Error?
    var selectedTab: AppTab = .links
    var linksScrollToTopRequestID: UInt = 0
    
    // List and filter state
    var selectedListId: String? = nil  // nil = Home timeline
    var isUserFilterOpen = false
    var userFilterPerFeedId: [String: String] = [:]  // feedId -> accountId
    var linksLastVisibleStatusIdPerFeed: [String: String] = [:]
    var currentAccountListDisplayPreferences = AccountListDisplayPreferences()
    
    // Navigation state (per-tab so switching tabs shows correct root)
    var linksNavigationPath: [NavigationDestination] = []
    var exploreNavigationPath: [NavigationDestination] = []
    var profileNavigationPath: [NavigationDestination] = []
    var mentionsNavigationPath: [NavigationDestination] = []
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

    var selectedLinkFeedID: String {
        selectedListId ?? Self.homeFeedID
    }

    private var currentAccountListDisplayPreferencesStorageKey: String? {
        guard let accountID = currentAccount?.id else { return nil }
        return Self.listDisplayPreferencesStorageKeyPrefix + accountID
    }
    
    func getAccessToken() async -> String? {
        guard let account = currentAccount else { return nil }
        return await authService.getAccessToken(for: account)
    }
    
    func getCurrentInstance() -> String? {
        currentAccount?.instance
    }

    // MARK: - List Display

    func loadListDisplayPreferencesForCurrentAccount(defaults: UserDefaults = .standard) {
        guard let storageKey = currentAccountListDisplayPreferencesStorageKey else {
            currentAccountListDisplayPreferences = AccountListDisplayPreferences()
            return
        }

        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? Self.listDisplayPreferencesDecoder.decode(
                  AccountListDisplayPreferences.self,
                  from: data
              ) else {
            currentAccountListDisplayPreferences = AccountListDisplayPreferences()
            return
        }

        currentAccountListDisplayPreferences = preferences
    }

    func persistListDisplayPreferencesForCurrentAccount(defaults: UserDefaults = .standard) {
        guard let storageKey = currentAccountListDisplayPreferencesStorageKey else { return }

        if currentAccountListDisplayPreferences == AccountListDisplayPreferences() {
            defaults.removeObject(forKey: storageKey)
            return
        }

        guard let data = try? Self.listDisplayPreferencesEncoder.encode(currentAccountListDisplayPreferences) else {
            Self.logger.error("Failed to encode list display preferences")
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    func resolvedListDisplay(for rawLists: [MastodonList]) -> AccountListDisplayResolution {
        AccountListDisplayResolver.resolve(
            lists: rawLists,
            preferences: currentAccountListDisplayPreferences
        )
    }

    @discardableResult
    func synchronizeCurrentAccountListDisplayPreferences(
        with rawLists: [MastodonList],
        allowEmptyListSet: Bool = false,
        defaults: UserDefaults = .standard
    ) -> AccountListDisplayResolution {
        let resolution = resolvedListDisplay(for: rawLists)
        guard !rawLists.isEmpty || allowEmptyListSet else {
            return resolution
        }

        if resolution.normalizedPreferences != currentAccountListDisplayPreferences {
            currentAccountListDisplayPreferences = resolution.normalizedPreferences
            persistListDisplayPreferencesForCurrentAccount(defaults: defaults)
        }

        reconcileVisibleFeedSelection(
            visibleListIDs: resolution.visibleListIDs,
            defaults: defaults
        )
        return resolution
    }

    func visibleLists(from rawLists: [MastodonList]) -> [MastodonList] {
        resolvedListDisplay(for: rawLists).visibleLists
    }

    func hiddenLists(from rawLists: [MastodonList]) -> [MastodonList] {
        resolvedListDisplay(for: rawLists).hiddenLists
    }

    func visibleListIDs(from rawLists: [MastodonList]) -> [String] {
        resolvedListDisplay(for: rawLists).visibleListIDs
    }

    func feedTabs(from rawLists: [MastodonList]) -> [FeedTabItem] {
        [FeedTabItem.home] + visibleLists(from: rawLists).map {
            FeedTabItem(id: $0.id, title: $0.title)
        }
    }

    func updateListDisplaySortOrder(
        _ sortOrder: ListDisplaySortOrder,
        rawLists: [MastodonList],
        defaults: UserDefaults = .standard
    ) {
        currentAccountListDisplayPreferences.sortOrder = sortOrder
        _ = synchronizeCurrentAccountListDisplayPreferences(with: rawLists, defaults: defaults)
    }

    func setListVisibility(
        listID: String,
        isVisible: Bool,
        rawLists: [MastodonList],
        defaults: UserDefaults = .standard
    ) {
        if isVisible {
            currentAccountListDisplayPreferences.hiddenListIDs.removeAll { $0 == listID }
            if currentAccountListDisplayPreferences.sortOrder == .custom,
               !currentAccountListDisplayPreferences.customVisibleListOrder.contains(listID) {
                currentAccountListDisplayPreferences.customVisibleListOrder.append(listID)
            }
        } else {
            if !currentAccountListDisplayPreferences.hiddenListIDs.contains(listID) {
                currentAccountListDisplayPreferences.hiddenListIDs.append(listID)
            }
            currentAccountListDisplayPreferences.customVisibleListOrder.removeAll { $0 == listID }
        }

        _ = synchronizeCurrentAccountListDisplayPreferences(with: rawLists, defaults: defaults)
    }

    func moveVisibleLists(
        fromOffsets: IndexSet,
        toOffset: Int,
        rawLists: [MastodonList],
        defaults: UserDefaults = .standard
    ) {
        var reorderedVisibleIDs = visibleListIDs(from: rawLists)
        moveIDs(&reorderedVisibleIDs, fromOffsets: fromOffsets, toOffset: toOffset)
        currentAccountListDisplayPreferences.sortOrder = .custom
        currentAccountListDisplayPreferences.customVisibleListOrder = reorderedVisibleIDs
        _ = synchronizeCurrentAccountListDisplayPreferences(with: rawLists, defaults: defaults)
    }

    private func reconcileVisibleFeedSelection(
        visibleListIDs: [String],
        defaults: UserDefaults
    ) {
        if let selectedListId, !visibleListIDs.contains(selectedListId) {
            self.selectedListId = nil
        }

        let defaultListID = defaults.string(forKey: Self.defaultListIdStorageKey) ?? ""
        if !defaultListID.isEmpty, !visibleListIDs.contains(defaultListID) {
            defaults.set("", forKey: Self.defaultListIdStorageKey)
        }
    }

    private func moveIDs(
        _ ids: inout [String],
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        let movingItems = fromOffsets.map { ids[$0] }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        for offset in fromOffsets.sorted(by: >) {
            ids.remove(at: offset)
        }
        let adjustedOffset = max(0, min(ids.count, toOffset - removedBeforeDestination))
        ids.insert(contentsOf: movingItems, at: adjustedOffset)
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
        } else {
            presentedAlert = AlertItem(
                title: "Error",
                message: error.localizedDescription
            )
            Self.logger.info("Presented generic error alert")
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
        func shouldReplaceArticle(path: [NavigationDestination]) -> Bool {
            if case .article = destination,
               case .article? = path.last {
                return true
            }
            return false
        }
        switch selectedTab {
        case .links:
            if shouldReplaceArticle(path: linksNavigationPath) {
                linksNavigationPath[linksNavigationPath.count - 1] = destination
            } else {
                linksNavigationPath.append(destination)
            }
        case .explore:
            if shouldReplaceArticle(path: exploreNavigationPath) {
                exploreNavigationPath[exploreNavigationPath.count - 1] = destination
            } else {
                exploreNavigationPath.append(destination)
            }
        case .profile:
            if shouldReplaceArticle(path: profileNavigationPath) {
                profileNavigationPath[profileNavigationPath.count - 1] = destination
            } else {
                profileNavigationPath.append(destination)
            }
        case .mentions:
            if shouldReplaceArticle(path: mentionsNavigationPath) {
                mentionsNavigationPath[mentionsNavigationPath.count - 1] = destination
            } else {
                mentionsNavigationPath.append(destination)
            }
        }
    }
    
    func navigateBack() {
        switch selectedTab {
        case .links:
            if !linksNavigationPath.isEmpty {
                let previous = linksNavigationPath.last
                linksNavigationPath.removeLast()
                Self.logger.info("Navigating back from: \(String(describing: previous), privacy: .public)")
            } else {
                Self.logger.debug("Navigate back called but navigation path is empty")
            }
        case .explore:
            if !exploreNavigationPath.isEmpty {
                let previous = exploreNavigationPath.last
                exploreNavigationPath.removeLast()
                Self.logger.info("Navigating back from: \(String(describing: previous), privacy: .public)")
            } else {
                Self.logger.debug("Navigate back called but navigation path is empty")
            }
        case .profile:
            if !profileNavigationPath.isEmpty {
                let previous = profileNavigationPath.last
                profileNavigationPath.removeLast()
                Self.logger.info("Navigating back from: \(String(describing: previous), privacy: .public)")
            } else {
                Self.logger.debug("Navigate back called but navigation path is empty")
            }
        case .mentions:
            if !mentionsNavigationPath.isEmpty {
                let previous = mentionsNavigationPath.last
                mentionsNavigationPath.removeLast()
                Self.logger.info("Navigating back from: \(String(describing: previous), privacy: .public)")
            } else {
                Self.logger.debug("Navigate back called but mentions navigation path is empty")
            }
        }
    }
    
    func navigateToRoot() {
        switch selectedTab {
        case .links:
            let count = linksNavigationPath.count
            linksNavigationPath.removeAll()
            Self.logger.info("Navigating to root, cleared \(count) destinations")
        case .explore:
            let count = exploreNavigationPath.count
            exploreNavigationPath.removeAll()
            Self.logger.info("Navigating to root, cleared \(count) destinations")
        case .profile:
            let count = profileNavigationPath.count
            profileNavigationPath.removeAll()
            Self.logger.info("Navigating to root, cleared \(count) destinations")
        case .mentions:
            let count = mentionsNavigationPath.count
            mentionsNavigationPath.removeAll()
            Self.logger.info("Navigating to root, cleared \(count) mentions destinations")
        }
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

    func requestLinksScrollToTop() {
        linksScrollToTopRequestID &+= 1
    }

    func resolvedDefaultLinkFeedID(defaultListId: String, availableListIDs: [String]) -> String {
        guard !defaultListId.isEmpty, availableListIDs.contains(defaultListId) else {
            return Self.homeFeedID
        }

        return defaultListId
    }

    @discardableResult
    func applyDefaultLinkFeed(defaultListId: String, availableListIDs: [String]) -> String {
        let feedID = resolvedDefaultLinkFeedID(
            defaultListId: defaultListId,
            availableListIDs: availableListIDs
        )
        selectedListId = feedID == Self.homeFeedID ? nil : feedID
        return feedID
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
        case .mentions: return "Messages"
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
    case conversation(GroupedConversation)
    case profile(MastodonAccount)
    case article(url: URL, status: Status?)
    case thread(statusId: String)
    case hashtag(String)
    case settings
    case listDisplay
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
