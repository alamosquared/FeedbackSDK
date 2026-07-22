import CryptoKit
import Foundation
import Security

enum IdentityStorage {
    private static let service = "com.alamosquared.feedback.sdk.identity"
    private static let account = "default"
    private static let accessGroupSuffix = "com.alamosquared.feedback.sdk.identity"

    struct StoredIdentity: Codable {
        let id: UUID
        let externalUserId: String?
        let label: String?
        let privateKey: Data
    }

    static func load(effectiveSyncEnabled: Bool) throws -> StoredIdentity? {
        if let identity = try loadSlot(
            synchronizable: effectiveSyncEnabled,
            includeAccessGroup: true
        ) {
            return identity
        }

        if let other = try loadSlot(
            synchronizable: !effectiveSyncEnabled,
            includeAccessGroup: true
        ) {
            try save(other, synchronizable: effectiveSyncEnabled)
            try delete(synchronizable: !effectiveSyncEnabled, includeAccessGroup: true)
            return other
        }

        guard resolvedAccessGroup != nil else {
            return nil
        }

        if let legacy = try loadSlot(
            synchronizable: effectiveSyncEnabled,
            includeAccessGroup: false
        ) {
            try save(legacy, synchronizable: effectiveSyncEnabled)
            try delete(synchronizable: effectiveSyncEnabled, includeAccessGroup: false)
            return legacy
        }

        if let legacyOther = try loadSlot(
            synchronizable: !effectiveSyncEnabled,
            includeAccessGroup: false
        ) {
            try save(legacyOther, synchronizable: effectiveSyncEnabled)
            try delete(synchronizable: !effectiveSyncEnabled, includeAccessGroup: false)
            return legacyOther
        }

        return nil
    }

    static func save(_ identity: StoredIdentity, synchronizable: Bool) throws {
        let data = try JSONEncoder().encode(identity)
        var query = baseQuery(includeAccessGroup: true, synchronizable: synchronizable)
        let accessibility = accessibility(forSynchronizable: synchronizable)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = accessibility
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw FeedbackSDKError.keychainError(addStatus)
            }
            return
        }

        throw FeedbackSDKError.keychainError(updateStatus)
    }

    static func delete(synchronizable: Bool, includeAccessGroup: Bool) throws {
        let query = baseQuery(includeAccessGroup: includeAccessGroup, synchronizable: synchronizable)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FeedbackSDKError.keychainError(status)
        }
    }

    static func deleteAll() throws {
        for synchronizable in [true, false] {
            for includeAccessGroup in [true, false] {
                try delete(synchronizable: synchronizable, includeAccessGroup: includeAccessGroup)
            }
        }
    }

    static func migrate(
        _ identity: StoredIdentity,
        fromSynchronizable sourceSynchronizable: Bool,
        toSynchronizable targetSynchronizable: Bool
    ) throws {
        guard sourceSynchronizable != targetSynchronizable else {
            return
        }

        try save(identity, synchronizable: targetSynchronizable)
        try delete(synchronizable: sourceSynchronizable, includeAccessGroup: true)
    }

    private static func loadSlot(
        synchronizable: Bool,
        includeAccessGroup: Bool
    ) throws -> StoredIdentity? {
        var query = baseQuery(includeAccessGroup: includeAccessGroup, synchronizable: synchronizable)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw FeedbackSDKError.keychainError(status)
        }

        return try JSONDecoder().decode(StoredIdentity.self, from: data)
    }

    private static func baseQuery(
        includeAccessGroup: Bool,
        synchronizable: Bool
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable,
        ]

        if includeAccessGroup, let resolvedAccessGroup {
            query[kSecAttrAccessGroup as String] = resolvedAccessGroup
        }

        return query
    }

    private static func accessibility(forSynchronizable synchronizable: Bool) -> CFString {
        synchronizable
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }

    private static var resolvedAccessGroup: String? {
        #if os(macOS)
            guard let task = SecTaskCreateFromSelf(nil) else {
                return nil
            }

            guard let value = SecTaskCopyValueForEntitlement(
                task,
                "keychain-access-groups" as CFString,
                nil
            ) else {
                return nil
            }

            guard let groups = value as? [String] else {
                return nil
            }

            return groups.first { $0.hasSuffix(accessGroupSuffix) } ?? groups.first
        #else
            guard let prefix = keychainAccessGroupPrefix() else {
                return nil
            }

            return "\(prefix).\(accessGroupSuffix)"
        #endif
    }

    #if !os(macOS)
        private static let accessGroupProbeAccount = "__feedback_sdk_access_group_probe__"
        private static let accessGroupProbeService = "\(service).access-group-probe"

        private static func keychainAccessGroupPrefix() -> String? {
            defer {
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: accessGroupProbeService,
                    kSecAttrAccount as String: accessGroupProbeAccount,
                ]
                SecItemDelete(deleteQuery as CFDictionary)
            }

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: accessGroupProbeService,
                kSecAttrAccount as String: accessGroupProbeAccount,
                kSecValueData as String: Data("probe".utf8),
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
                return nil
            }

            guard let accessGroup = readAccessGroup(
                service: accessGroupProbeService,
                account: accessGroupProbeAccount
            ) else {
                return nil
            }

            return accessGroup.split(separator: ".").first.map(String.init)
        }

        private static func readAccessGroup(service: String, account: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess,
                  let attributes = item as? [String: Any],
                  let accessGroup = attributes[kSecAttrAccessGroup as String] as? String
            else {
                return nil
            }

            return accessGroup
        }
    #endif
}

enum RequestSigning {
    static func signedHeaders(
        identity: CustomerIdentity,
        privateKey: Curve25519.Signing.PrivateKey,
        method: String,
        url: URL,
        body: Data
    ) throws -> [String: String] {
        let timestampMs = String(Int64(Date().timeIntervalSince1970 * 1000))
        let path = url.path
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        let bodyHash = SHA256.hash(data: Data(bodyString.utf8))
        let bodyHashHex = bodyHash.map { String(format: "%02x", $0) }.joined()
        let payload = "\(timestampMs)\n\(method.uppercased())\n\(path)\n\(bodyHashHex)"
        let signature = try privateKey.signature(for: Data(payload.utf8))

        return [
            "X-Feedback-Identity": identity.id.urlId,
            "X-Feedback-Timestamp": timestampMs,
            "X-Feedback-Signature": Data(signature).base64URLEncodedString(),
        ]
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension Curve25519.Signing.PrivateKey {
    static func generate() -> Curve25519.Signing.PrivateKey {
        Curve25519.Signing.PrivateKey()
    }

    var publicKeyBase64URL: String {
        publicKey.rawRepresentation.base64URLEncodedString()
    }
}
