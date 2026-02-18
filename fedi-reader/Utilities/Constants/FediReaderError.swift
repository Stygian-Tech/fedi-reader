import Foundation

enum FediReaderError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error)
    case noActiveAccount
    case oauthError(String)
    case readLaterError(String)
    
    static func == (lhs: FediReaderError, rhs: FediReaderError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.noActiveAccount, .noActiveAccount):
            return true
        case (.rateLimited(let lhsRetry), .rateLimited(let rhsRetry)):
            return lhsRetry == rhsRetry
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.oauthError(let lhsMessage), .oauthError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.readLaterError(let lhsMessage), .readLaterError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Please try again in \(Int(retry)) seconds."
            }
            return "Rate limited. Please try again later."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noActiveAccount:
            return "No active account. Please log in."
        case .oauthError(let message):
            return "Authentication error: \(message)"
        case .readLaterError(let message):
            return "Read later error: \(message)"
        }
    }
}

