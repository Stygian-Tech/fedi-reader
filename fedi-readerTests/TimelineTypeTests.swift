import Testing
import Foundation
@testable import fedi_reader

@Suite("Timeline Type Tests")
struct TimelineTypeTests {
    
    @Test("All timeline types have display names")
    func allTypesHaveDisplayNames() {
        for type in TimelineType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }
    
    @Test("All timeline types have system images")
    func allTypesHaveSystemImages() {
        for type in TimelineType.allCases {
            #expect(!type.systemImage.isEmpty)
        }
    }
    
    @Test("Expected timeline types exist")
    func expectedTypesExist() {
        let types = TimelineType.allCases
        
        #expect(types.contains(.home))
        #expect(types.contains(.mentions))
        #expect(types.contains(.explore))
        #expect(types.contains(.links))
    }
    
    @Test("Mentions timeline uses Messages display name")
    func mentionsTimelineUsesMessagesDisplayName() {
        #expect(TimelineType.mentions.displayName == "Messages")
    }
}

// MARK: - App Tab Tests


