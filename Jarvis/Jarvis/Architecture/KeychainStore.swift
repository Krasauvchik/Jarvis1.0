import Foundation
import Security

/// Secure storage for secrets (API keys, tokens) backed by the iOS/macOS Keychain.
///
/// Why this exists: secrets must never live in `UserDefaults`, which is an unencrypted
/// plist readable from a device backup or a jailbroken/compromised device. The Keychain
/// keeps values in the Secure Enclave-protected store and is gated by device unlock.
///
/// Items are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
/// available to the app after the first unlock following a reboot, never synced to iCloud,
/// and never included in encrypted backups that move to another device.
enum KeychainStore {
    /// Keychain service namespace — scoped to the app bundle to avoid collisions.
    private static let service: String = {
        (Bundle.main.bundleIdentifier ?? "com.jarvis.planner") + ".secrets"
    }()

    /// Stores (or, with `nil`/empty value, removes) a secret for the given account key.
    @discardableResult
    static func set(_ value: String?, for account: String) -> Bool {
        guard let value, !value.isEmpty else { return delete(account) }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Update in place if the item already exists, otherwise add it.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            let addStatus = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return false
    }

    /// Reads a secret for the given account key, or `nil` if absent.
    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Removes a secret. Returns `true` if it was deleted or already absent.
    @discardableResult
    static func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
