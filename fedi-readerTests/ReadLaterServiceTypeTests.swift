import Testing
import Foundation
@testable import fedi_reader

@Suite("Read Later Service Type Tests")
struct ReadLaterServiceTypeTests {
    
    @Test("All service types have display names")
    func allTypesHaveDisplayNames() {
        for type in ReadLaterServiceType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }
    
    @Test("All service types have icon names")
    func allTypesHaveIconNames() {
        for type in ReadLaterServiceType.allCases {
            #expect(!type.iconName.isEmpty)
        }
    }
    
    @Test("Service type identifiable conformance")
    func serviceTypeIdentifiable() {
        for type in ReadLaterServiceType.allCases {
            #expect(type.id == type.rawValue)
        }
    }
    
    @Test("Expected service types exist")
    func expectedTypesExist() {
        let types = ReadLaterServiceType.allCases
        
        #expect(types.contains(.pocket))
        #expect(types.contains(.instapaper))
        #expect(types.contains(.omnivore))
        #expect(types.contains(.readwise))
        #expect(types.contains(.raindrop))
    }
}

// MARK: - Timeline Type Tests


