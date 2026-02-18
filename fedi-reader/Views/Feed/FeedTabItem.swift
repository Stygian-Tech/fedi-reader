import SwiftUI

struct FeedTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let isHome: Bool
    
    init(id: String, title: String, isHome: Bool = false) {
        self.id = id
        self.title = title
        self.isHome = isHome
    }
    
    static let home = FeedTabItem(id: "home", title: "Home", isHome: true)
}

// MARK: - Link Feed View


