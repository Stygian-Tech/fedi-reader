//
//  ReadLaterTests.swift
//  fedi-readerTests
//
//  Read-later manager and Instapaper integration tests
//

import Testing
import Foundation
@testable import fedi_reader

private final class InstapaperMockURLProtocol: URLProtocol {
    static var responseData = Data()
    static var statusCode = 201
    static var lastRequest: URLRequest?
    static var lastRequestBody: Data?
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? requestBodyData(from: request.httpBodyStream)
        
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
    
    static func reset() {
        responseData = Data()
        statusCode = 201
        lastRequest = nil
        lastRequestBody = nil
    }
    
    private func requestBodyData(from stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        
        stream.open()
        defer { stream.close() }
        
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return data.isEmpty ? nil : data
    }
}

private actor NotificationResultStore {
    private(set) var result: ReadLaterSaveResult?
    
    func set(_ newValue: ReadLaterSaveResult?) {
        result = newValue
    }
}

@Suite("Read Later Manager Tests")
@MainActor
struct ReadLaterManagerTests {
    @Test("save posts failure notification when service is not configured")
    func savePostsFailureNotificationWhenServiceMissing() async {
        let manager = ReadLaterManager()
        let articleURL = URL(string: "https://example.com/article")!
        let resultStore = NotificationResultStore()
        
        let observer = NotificationCenter.default.addObserver(
            forName: .readLaterDidSave,
            object: nil,
            queue: nil
        ) { notification in
            Task {
                await resultStore.set(notification.object as? ReadLaterSaveResult)
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        do {
            try await manager.save(url: articleURL, title: "Example", to: .instapaper)
            Issue.record("Expected save to throw when Instapaper is not configured")
        } catch {
            // Expected path
        }
        
        let receivedResult = await resultStore.result
        #expect(receivedResult != nil)
        #expect(receivedResult?.success == false)
        #expect(receivedResult?.serviceType == .instapaper)
        #expect(receivedResult?.url == articleURL)
    }
}

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
