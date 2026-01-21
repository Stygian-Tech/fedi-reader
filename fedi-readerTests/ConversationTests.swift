//
//  ConversationTests.swift
//  fedi-readerTests
//
//  Tests for conversation/chat functionality
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("Conversation Tests")
struct ConversationTests {
    
    // MARK: - Conversation Model
    
    @Test("Creates conversation with messages")
    func createsConversation() {
        let account = MockStatusFactory.makeAccount()
        let notification = MockStatusFactory.makeNotification()
        let message = ChatMessage(notification: notification)
        
        let conversation = Conversation(account: account, messages: [message])
        
        #expect(conversation.id == account.id)
        #expect(conversation.account.id == account.id)
        #expect(conversation.messages.count == 1)
        #expect(conversation.lastMessage?.id == message.id)
    }
    
    @Test("Gets last message preview")
    func getsLastMessagePreview() {
        let account = MockStatusFactory.makeAccount()
        let status = MockStatusFactory.makeStatus(content: "<p>Hello world</p>")
        let notification = MockStatusFactory.makeNotification(status: status)
        let message = ChatMessage(notification: notification)
        
        let conversation = Conversation(account: account, messages: [message])
        
        #expect(conversation.lastMessagePreview.contains("Hello world"))
    }
    
    @Test("Sorts conversations by last message date")
    func sortsConversationsByDate() {
        let account1 = MockStatusFactory.makeAccount(id: "1")
        let account2 = MockStatusFactory.makeAccount(id: "2")
        
        let oldDate = Date().addingTimeInterval(-3600)
        let newDate = Date()
        
        let oldNotification = MastodonNotification(
            id: "old",
            type: .mention,
            createdAt: oldDate,
            account: account1,
            status: MockStatusFactory.makeStatus()
        )
        let newNotification = MastodonNotification(
            id: "new",
            type: .mention,
            createdAt: newDate,
            account: account2,
            status: MockStatusFactory.makeStatus()
        )
        
        let conversation1 = Conversation(
            account: account1,
            messages: [ChatMessage(notification: oldNotification)]
        )
        let conversation2 = Conversation(
            account: account2,
            messages: [ChatMessage(notification: newNotification)]
        )
        
        let sorted = [conversation1, conversation2].sorted { $0.lastMessageDate > $1.lastMessageDate }
        
        #expect(sorted.first?.account.id == "2")
    }
    
    // MARK: - ChatMessage Model
    
    @Test("Creates chat message from notification")
    func createsMessageFromNotification() {
        let notification = MockStatusFactory.makeNotification()
        let message = ChatMessage(notification: notification)
        
        #expect(message.id == notification.id)
        #expect(message.notification?.id == notification.id)
        #expect(message.isSent == false)
        #expect(message.status?.id == notification.status?.id)
    }
    
    @Test("Creates sent chat message from status")
    func createsSentMessageFromStatus() {
        let status = MockStatusFactory.makeStatus()
        let message = ChatMessage(status: status, isSent: true)
        
        #expect(message.id == status.id)
        #expect(message.status?.id == status.id)
        #expect(message.isSent == true)
        #expect(message.notification == nil)
    }
    
    // MARK: - GroupedMessage Model
    
    @Test("Groups messages by sender")
    func groupsMessagesBySender() {
        let account = MockStatusFactory.makeAccount()
        let message1 = ChatMessage(notification: MockStatusFactory.makeNotification(id: "1"))
        let message2 = ChatMessage(notification: MockStatusFactory.makeNotification(id: "2"))
        
        let group = GroupedMessage(account: account, messages: [message1, message2], isSent: false)
        
        #expect(group.id.contains(account.id))
        #expect(group.messages.count == 2)
        #expect(group.isSent == false)
    }
    
    @Test("Creates sent message group")
    func createsSentMessageGroup() {
        let account = MockStatusFactory.makeAccount()
        let status = MockStatusFactory.makeStatus()
        let message = ChatMessage(status: status, isSent: true)
        
        let group = GroupedMessage(account: account, messages: [message], isSent: true)
        
        #expect(group.isSent == true)
        #expect(group.messages.first?.isSent == true)
    }
    
    // MARK: - Conversation Building
    
    @Test("Builds conversations from mentions")
    func buildsConversations() {
        let account1 = MockStatusFactory.makeAccount(id: "account1", username: "user1")
        let account2 = MockStatusFactory.makeAccount(id: "account2", username: "user2")
        
        let status1 = MockStatusFactory.makeStatus(
            id: "status1",
            visibility: .private
        )
        let status2 = MockStatusFactory.makeStatus(
            id: "status2",
            visibility: .direct
        )
        
        let notification1 = MastodonNotification(
            id: "notif1",
            type: .mention,
            createdAt: Date(),
            account: account1,
            status: status1
        )
        let notification2 = MastodonNotification(
            id: "notif2",
            type: .mention,
            createdAt: Date(),
            account: account2,
            status: status2
        )
        
        let mentions = [notification1, notification2]
        
        // Simulate the buildConversations logic
        let groupedByAccount = Dictionary(grouping: mentions) { $0.account.id }
        let conversations = groupedByAccount.values.compactMap { notifications -> Conversation? in
            guard let firstNotification = notifications.first,
                  firstNotification.status != nil else { return nil }
            
            let sortedNotifications = notifications.sorted { $0.createdAt > $1.createdAt }
            return Conversation(
                account: firstNotification.account,
                messages: sortedNotifications.map { ChatMessage(notification: $0) }
            )
        }
        
        #expect(conversations.count == 2)
        #expect(conversations.contains { $0.account.id == "account1" })
        #expect(conversations.contains { $0.account.id == "account2" })
    }
    
    @Test("Filters private and direct messages only")
    func filtersPrivateMessages() {
        let privateStatus = MockStatusFactory.makeStatus(visibility: .private)
        let directStatus = MockStatusFactory.makeStatus(visibility: .direct)
        let publicStatus = MockStatusFactory.makeStatus(visibility: .public)
        
        let notifications = [
            MastodonNotification(id: "1", type: .mention, createdAt: Date(), account: MockStatusFactory.makeAccount(), status: privateStatus),
            MastodonNotification(id: "2", type: .mention, createdAt: Date(), account: MockStatusFactory.makeAccount(), status: directStatus),
            MastodonNotification(id: "3", type: .mention, createdAt: Date(), account: MockStatusFactory.makeAccount(), status: publicStatus)
        ]
        
        let filtered = notifications.filter { notification in
            guard let status = notification.status else { return false }
            return status.visibility == .private || status.visibility == .direct
        }
        
        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.id == "1" })
        #expect(filtered.contains { $0.id == "2" })
        #expect(!filtered.contains { $0.id == "3" })
    }
    
    // MARK: - Account Extension
    
    @Test("Converts Account to MastodonAccount")
    func convertsAccountToMastodonAccount() {
        let account = Account(
            id: "mastodon.social:123",
            instance: "mastodon.social",
            username: "testuser",
            displayName: "Test User",
            avatarURL: "https://example.com/avatar.jpg",
            headerURL: "https://example.com/header.jpg",
            acct: "testuser@mastodon.social",
            note: "Test bio",
            followersCount: 100,
            followingCount: 50,
            statusesCount: 200
        )
        
        let mastodonAccount = account.mastodonAccount
        
        #expect(mastodonAccount.id == "123")
        #expect(mastodonAccount.username == "testuser")
        #expect(mastodonAccount.displayName == "Test User")
        #expect(mastodonAccount.acct == "testuser@mastodon.social")
        #expect(mastodonAccount.followersCount == 100)
    }
    
    @Test("Handles account ID without colon separator")
    func handlesAccountIdWithoutColon() {
        let account = Account(
            id: "123",
            instance: "mastodon.social",
            username: "testuser",
            displayName: "Test User",
            acct: "testuser@mastodon.social"
        )
        
        let mastodonAccount = account.mastodonAccount
        
        #expect(mastodonAccount.id == "123")
    }
}
