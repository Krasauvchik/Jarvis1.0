import Foundation

/// Typed accessors for the app's secrets, backed by `KeychainStore`.
///
/// All secret reads/writes in the app go through here so there is a single,
/// auditable boundary for sensitive material. Plain (non-secret) preferences
/// stay in `UserDefaults`; only API keys and tokens live in the Keychain.
///
/// On first read of each secret we transparently migrate any legacy value that
/// was previously stored in `UserDefaults`, then scrub it from the plist.
enum SecretStore {
    /// Logical secret identities. The raw value doubles as the Keychain account
    /// and the legacy `UserDefaults` key we migrate away from.
    enum Key: String, CaseIterable {
        case backendAPIKey = "jarvis_api_key"
        case geminiAPIKey = "jarvis_gemini_api_key"
        case yandexAPIKey = "jarvis_yandexgpt_api_key"
    }

    /// Reads a secret, migrating a legacy `UserDefaults` value into the Keychain on first access.
    static func get(_ key: Key) -> String? {
        if let value = KeychainStore.get(key.rawValue), !value.isEmpty {
            return value
        }
        // One-time migration: lift any legacy plaintext value out of UserDefaults.
        if let legacy = UserDefaults.standard.string(forKey: key.rawValue), !legacy.isEmpty {
            KeychainStore.set(legacy, for: key.rawValue)
            UserDefaults.standard.removeObject(forKey: key.rawValue)
            return legacy
        }
        return nil
    }

    /// Stores (or clears, on empty/nil) a secret in the Keychain.
    static func set(_ value: String?, for key: Key) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.set(trimmed, for: key.rawValue)
        // Defensively ensure no stale copy lingers in UserDefaults.
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }

    /// Migrates every known legacy secret out of `UserDefaults` in one pass.
    /// Safe to call repeatedly (e.g. at launch); a no-op once migrated.
    static func migrateLegacySecretsIfNeeded() {
        for key in Key.allCases {
            _ = get(key)
        }
    }
}
