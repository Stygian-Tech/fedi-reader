import Foundation

extension MastodonNotification: Equatable {
    static func == (lhs: MastodonNotification, rhs: MastodonNotification) -> Bool {
        lhs.id == rhs.id
    }
}


