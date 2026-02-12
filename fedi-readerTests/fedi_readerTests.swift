//
//  fedi_readerTests.swift
//  fedi-readerTests
//
//  Main test file and additional service tests
//

import Testing
import Foundation
@testable import fedi_reader

// MARK: - Read Later Service Type Tests

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

@Suite("Constants Tests")
struct ConstantsTests {
    
    @Test("App name is set")
    func appNameIsSet() {
        #expect(!Constants.appName.isEmpty)
        #expect(Constants.appName == "Fedi Reader")
    }
    
    @Test("OAuth constants are set")
    func oauthConstantsSet() {
        #expect(!Constants.OAuth.redirectScheme.isEmpty)
        #expect(!Constants.OAuth.redirectURI.isEmpty)
        #expect(!Constants.OAuth.scopes.isEmpty)
    }
    
    @Test("API paths are set")
    func apiPathsSet() {
        #expect(!Constants.API.homeTimeline.isEmpty)
        #expect(!Constants.API.verifyCredentials.isEmpty)
        #expect(!Constants.API.statuses.isEmpty)
    }
    
    @Test("Pagination defaults are reasonable")
    func paginationDefaults() {
        #expect(Constants.Pagination.defaultLimit > 0)
        #expect(Constants.Pagination.maxLimit >= Constants.Pagination.defaultLimit)
        #expect(Constants.Pagination.prefetchThreshold > 0)
    }
}

// MARK: - Error Type Tests

@Suite("Error Type Tests")
struct ErrorTypeTests {
    
    @Test("FediReaderError has localized descriptions")
    func errorsHaveDescriptions() {
        let errors: [FediReaderError] = [
            .invalidURL,
            .invalidResponse,
            .unauthorized,
            .rateLimited(retryAfter: 60),
            .serverError(statusCode: 500, message: "Server error"),
            .noActiveAccount,
            .oauthError("Test"),
            .readLaterError("Test")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("Rate limited error includes retry time")
    func rateLimitedIncludesRetryTime() {
        let error = FediReaderError.rateLimited(retryAfter: 60)
        
        #expect(error.errorDescription?.contains("60") == true)
    }
    
    @Test("Server error includes status code")
    func serverErrorIncludesCode() {
        let error = FediReaderError.serverError(statusCode: 503, message: nil)
        
        #expect(error.errorDescription?.contains("503") == true)
    }
}

// MARK: - Link Status Tests

@Suite("Link Status Tests")
struct LinkStatusTests {
    
    @Test("LinkStatus correctly extracts domain")
    func linkStatusExtractsDomain() {
        let status = MockStatusFactory.makeStatus(hasCard: true, cardURL: "https://example.com/article")
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com/article")!,
            title: "Test"
        )
        
        #expect(linkStatus.domain == "example.com")
    }
    
    @Test("LinkStatus uses title for displayTitle")
    func linkStatusDisplayTitle() {
        let status = MockStatusFactory.makeStatus()
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            title: "My Article"
        )
        
        #expect(linkStatus.displayTitle == "My Article")
    }
    
    @Test("LinkStatus falls back to host for displayTitle")
    func linkStatusDisplayTitleFallback() {
        let status = MockStatusFactory.makeStatus()
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            title: nil
        )
        
        #expect(linkStatus.displayTitle == "example.com")
    }
    
    @Test("LinkStatus hasImage property")
    func linkStatusHasImage() {
        let status = MockStatusFactory.makeStatus()
        
        let withImage = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            imageURL: URL(string: "https://example.com/image.jpg")
        )
        
        let withoutImage = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            imageURL: nil
        )
        
        #expect(withImage.hasImage == true)
        #expect(withoutImage.hasImage == false)
    }
}
