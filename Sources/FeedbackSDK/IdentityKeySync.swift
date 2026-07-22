import Foundation

enum IdentityKeySync {
    static let userPreferenceKey = "com.alamosquared.feedback.sdk.identitySyncEnabled"

    static func effectiveSyncEnabled(
        policy: IdentityKeySyncPolicy,
        storedPreference: Bool?
    ) -> Bool {
        switch policy {
        case .iCloud:
            return true
        case .deviceOnly:
            return false
        case let .userConfigurable(defaultSyncs):
            return storedPreference ?? defaultSyncs
        }
    }

    static func isRuntimeConfigurable(_ policy: IdentityKeySyncPolicy) -> Bool {
        if case .userConfigurable = policy {
            return true
        }
        return false
    }

    static func storedPreference() -> Bool? {
        guard UserDefaults.standard.object(forKey: userPreferenceKey) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: userPreferenceKey)
    }

    static func setStoredPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userPreferenceKey)
    }
}
