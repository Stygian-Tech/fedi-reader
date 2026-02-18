import Foundation
import SwiftData

struct ReadLaterSaveResult: Sendable {
    let success: Bool
    let url: URL
    let serviceType: ReadLaterServiceType
    let itemId: String?
    let error: Error?
    
    static func success(url: URL, service: ReadLaterServiceType, itemId: String? = nil) -> ReadLaterSaveResult {
        ReadLaterSaveResult(success: true, url: url, serviceType: service, itemId: itemId, error: nil)
    }
    
    static func failure(url: URL, service: ReadLaterServiceType, error: Error) -> ReadLaterSaveResult {
        ReadLaterSaveResult(success: false, url: url, serviceType: service, itemId: nil, error: error)
    }
}

