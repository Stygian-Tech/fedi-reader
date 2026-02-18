import Testing
import Foundation
@testable import fedi_reader

@Suite("App Tab Tests")
struct AppTabTests {
    
    @Test("All tabs have titles")
    func allTabsHaveTitles() {
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
        }
    }
    
    @Test("All tabs have system images")
    func allTabsHaveSystemImages() {
        for tab in AppTab.allCases {
            #expect(!tab.systemImage.isEmpty)
        }
    }
    
    @Test("Expected tabs exist")
    func expectedTabsExist() {
        let tabs = AppTab.allCases
        
        #expect(tabs.contains(.links))
        #expect(tabs.contains(.explore))
        #expect(tabs.contains(.mentions))
        #expect(tabs.contains(.profile))
    }
    
    @Test("Mentions tab uses Messages title")
    func mentionsTabUsesMessagesTitle() {
        #expect(AppTab.mentions.title == "Messages")
    }
}

// MARK: - Constants Tests


