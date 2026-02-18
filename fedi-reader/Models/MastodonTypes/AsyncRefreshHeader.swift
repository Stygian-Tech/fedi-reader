import Foundation

struct AsyncRefreshHeader: Sendable {
    let id: String
    let retrySeconds: Int
    let resultCount: Int?
    
    /// Parses the raw header value. Returns nil if missing or malformed.
    static func parse(headerValue: String?) -> AsyncRefreshHeader? {
        guard let raw = headerValue?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        var id: String?
        var retrySeconds: Int?
        var resultCount: Int?
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            if part.hasPrefix("id=\"") && part.hasSuffix("\"") {
                let start = part.index(part.startIndex, offsetBy: 4)
                let end = part.index(part.endIndex, offsetBy: -1)
                id = String(part[start..<end])
            } else if part.hasPrefix("retry=") {
                retrySeconds = Int(part.dropFirst(6))
            } else if part.hasPrefix("result_count=") {
                resultCount = Int(part.dropFirst(13))
            }
        }
        guard let id = id, let retry = retrySeconds, !id.isEmpty, retry > 0 else { return nil }
        return AsyncRefreshHeader(id: id, retrySeconds: retry, resultCount: resultCount)
    }
}

// MARK: - Async Refresh (API entity)


