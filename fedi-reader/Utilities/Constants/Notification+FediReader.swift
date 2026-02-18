import Foundation

extension Notification.Name {
    static let accountDidChange = Notification.Name("accountDidChange")
    static let accountDidLogin = Notification.Name("accountDidLogin")
    static let accountDidLogout = Notification.Name("accountDidLogout")
    static let timelineDidRefresh = Notification.Name("timelineDidRefresh")
    static let statusDidUpdate = Notification.Name("statusDidUpdate")
    static let readLaterDidSave = Notification.Name("readLaterDidSave")
    static let statusContextDidUpdate = Notification.Name("statusContextDidUpdate")
}

// MARK: - Notification Payloads


