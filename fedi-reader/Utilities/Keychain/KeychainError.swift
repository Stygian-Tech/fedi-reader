import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .itemNotFound:
            return "Item not found in Keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}


