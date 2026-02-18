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

