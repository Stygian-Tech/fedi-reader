import Testing
import Foundation
@testable import fedi_reader

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


