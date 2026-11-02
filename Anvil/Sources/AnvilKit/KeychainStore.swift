// MARK: - Keychain-backed credential store

import Foundation
import Security

public enum KeychainError: Error, Sendable {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unexpected(OSStatus)
}

/// Reads/writes provider API keys to the macOS Keychain (SPEC: keys never in repo).
@MainActor
public final class KeychainStore: Sendable {
    public static let shared = KeychainStore()
    private let service = "ai.anvil.desktop"

    private init() {}

    public func set(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.invalidData }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            throw KeychainError.duplicateItem
        }
        if status != errSecSuccess {
            throw KeychainError.unexpected(status)
        }
    }

    public func get(_ key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }
        if status != errSecSuccess {
            throw KeychainError.unexpected(status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    public func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpected(status)
        }
    }

    public func hasKey(_ key: String) -> Bool {
        (try? get(key)) != nil
    }
}
