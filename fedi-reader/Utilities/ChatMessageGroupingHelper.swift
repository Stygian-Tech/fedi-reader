import Foundation

enum ChatMessageGroupingHelper {
    static func groupMessages(
        _ messages: [ChatMessage],
        isGroupChat: Bool,
        unknownAccount: MastodonAccount
    ) -> [GroupedMessage] {
        var groups: [GroupedMessage] = []
        var currentGroup: [ChatMessage] = []
        var currentSenderId: String?

        for message in messages {
            let senderId = message.status?.account.id ?? "unknown"

            if senderId == currentSenderId {
                currentGroup.append(message)
                continue
            }

            appendCurrentGroup(
                &groups,
                currentGroup: currentGroup,
                isGroupChat: isGroupChat,
                unknownAccount: unknownAccount
            )

            currentGroup = [message]
            currentSenderId = senderId
        }

        appendCurrentGroup(
            &groups,
            currentGroup: currentGroup,
            isGroupChat: isGroupChat,
            unknownAccount: unknownAccount
        )

        return groups
    }

    private static func appendCurrentGroup(
        _ groups: inout [GroupedMessage],
        currentGroup: [ChatMessage],
        isGroupChat: Bool,
        unknownAccount: MastodonAccount
    ) {
        guard let firstMessage = currentGroup.first else { return }
        let account = firstMessage.status?.account ?? unknownAccount
        groups.append(
            GroupedMessage(
                account: account,
                messages: currentGroup,
                isSent: firstMessage.isSent,
                isGroupChat: isGroupChat
            )
        )
    }
}
