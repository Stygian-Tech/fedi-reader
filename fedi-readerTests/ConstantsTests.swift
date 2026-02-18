import Testing
import Foundation
@testable import fedi_reader

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


