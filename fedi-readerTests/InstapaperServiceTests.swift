import Testing
import Foundation
@testable import fedi_reader

@Suite("Instapaper Service Tests")
@MainActor
struct InstapaperServiceTests {
    @Test("save uses basic auth credentials and Instapaper add endpoint")
    func saveUsesBasicAuthCredentials() async throws {
        InstapaperMockURLProtocol.reset()
        defer {
            InstapaperMockURLProtocol.reset()
        }
        
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [InstapaperMockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        
        let config = ReadLaterConfig(serviceType: ReadLaterServiceType.instapaper.rawValue)
        let service = InstapaperService(
            config: config,
            keychain: .shared,
            session: session,
            loadStoredCredentials: false
        )
        
        try await service.authenticateWithCredentials(
            username: "user@example.com",
            password: "pass:word",
            persistCredentials: false
        )
        
        try await service.save(
            url: URL(string: "https://example.com/path?a=1")!,
            title: "Example & Title"
        )
        
        guard let request = InstapaperMockURLProtocol.lastRequest else {
            Issue.record("Expected Instapaper request to be captured")
            return
        }
        
        #expect(request.url?.absoluteString == Constants.ReadLater.instapaperAddURL)
        
        let expectedHeader = "Basic \(Data("user@example.com:pass:word".utf8).base64EncodedString())"
        #expect(request.value(forHTTPHeaderField: "Authorization") == expectedHeader)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        
        guard let bodyData = InstapaperMockURLProtocol.lastRequestBody,
              let bodyString = String(data: bodyData, encoding: .utf8) else {
            Issue.record("Expected request body for Instapaper save")
            return
        }
        
        #expect(bodyString.contains("url=https%3A%2F%2Fexample.com%2Fpath%3Fa%3D1"))
        #expect(bodyString.contains("title=Example%20%26%20Title"))
    }
}

