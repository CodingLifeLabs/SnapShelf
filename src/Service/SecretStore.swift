import Foundation
import Security
import os

// Sprint 4: secret (API key) storage. Production uses Keychain; tests use an in-memory store.

public protocol SecretStore: Sendable {
    func read(_ key: String) -> String?
    func write(_ key: String, value: String)
    func delete(_ key: String)
}

/// Keychain-backed secret store. Service identifier scopes entries to SnapShelf.
public struct KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "app.snapshelf.ai") {
        self.service = service
    }

    public func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    public func write(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    public func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory secret store for tests and previews. Lock-protected, Sendable.
public final class MemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [String: String]())

    public init() {}

    public func read(_ key: String) -> String? {
        lock.withLock { $0[key] }
    }

    public func write(_ key: String, value: String) {
        lock.withLock { $0[key] = value }
    }

    public func delete(_ key: String) {
        lock.withLock { $0[key] = nil }
    }
}
