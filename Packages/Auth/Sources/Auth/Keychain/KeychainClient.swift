import Foundation
import Security

/// Minimal abstraction over Keychain Services. Exposed as a protocol so
/// tests can substitute an in-memory implementation.
public protocol KeychainClient: Sendable {
    func get(key: String) async throws -> Data?
    func set(key: String, value: Data) async throws
    func delete(key: String) async throws
    func deleteAll() async throws
}

/// Errors thrown by Keychain operations.
public enum KeychainError: Error, Sendable, Equatable {
    case unhandled(status: OSStatus)
    case unexpectedItemType
    case interactionRequired
}

/// Live implementation of `KeychainClient` backed by the iOS Keychain.
///
/// All items are stored under a single service identifier so reads and
/// deletes can be scoped per-account (key) without leaking across the app's
/// other keychain usage. Items use
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so they survive
/// reboots but never sync to iCloud.
public actor LiveKeychainClient: KeychainClient {
    public let service: String
    public let accessGroup: String?

    public init(service: String = "app.workspaceterminal.ios.keychain", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func get(key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedItemType }
            return data
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed:
            throw KeychainError.interactionRequired
        default:
            throw KeychainError.unhandled(status: status)
        }
    }

    public func set(key: String, value: Data) throws {
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(status: addStatus)
            }
        default:
            throw KeychainError.unhandled(status: updateStatus)
        }
    }

    public func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    public func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

/// In-memory `KeychainClient` for tests.
public actor InMemoryKeychainClient: KeychainClient {
    private var storage: [String: Data] = [:]

    public init() {}

    public func get(key: String) async throws -> Data? { storage[key] }
    public func set(key: String, value: Data) async throws { storage[key] = value }
    public func delete(key: String) async throws { storage.removeValue(forKey: key) }
    public func deleteAll() async throws { storage.removeAll() }
}
