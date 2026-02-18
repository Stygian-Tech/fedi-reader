import Foundation
@testable import fedi_reader

actor MockKeychainHelper {
    private var storage: [String: Data] = [:]
    
    func save(_ data: Data, forKey key: String) throws {
        storage[key] = data
    }
    
    func save(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        storage[key] = data
    }
    
    func read(forKey key: String) throws -> Data {
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func readString(forKey key: String) throws -> String {
        let data = try read(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }
    
    func exists(forKey key: String) -> Bool {
        storage[key] != nil
    }
    
    func reset() {
        storage.removeAll()
    }
}

