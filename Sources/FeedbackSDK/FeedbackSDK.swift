import CryptoKit
import Foundation

public enum FeedbackSDK {
    private static let lock = NSLock()
    private static var configuration: Configuration?
    private static var identityKeySyncPolicy: IdentityKeySyncPolicy = .iCloud
    private static var keychainLoadAttempted = false

    public struct Configuration: Sendable {
        public let apiKey: String
        public let baseURL: URL
        public let session: URLSession
        public let defaultMetadata: [String: String]
        public let includeAutomaticMetadata: Bool
        /// When `true`, includes `UIDevice.identifierForVendor` as `idfv` in automatic metadata.
        public let includeVendorIdentifier: Bool
        public let identity: CustomerIdentity?

        fileprivate let signingKey: Curve25519.Signing.PrivateKey?

        public init(
            apiKey: String,
            baseURL: URL,
            session: URLSession = .shared,
            defaultMetadata: [String: String] = [:],
            includeAutomaticMetadata: Bool = true,
            includeVendorIdentifier: Bool = false,
            identity: CustomerIdentity? = nil,
            signingKey: Curve25519.Signing.PrivateKey? = nil
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.session = session
            self.defaultMetadata = defaultMetadata
            self.includeAutomaticMetadata = includeAutomaticMetadata
            self.includeVendorIdentifier = includeVendorIdentifier
            self.identity = identity
            self.signingKey = signingKey
        }
    }

    /// Device and app metadata gathered automatically on each submission.
    public static func automaticMetadata() -> [String: String] {
        lock.lock()
        let includeVendorIdentifier = configuration?.includeVendorIdentifier ?? false
        lock.unlock()

        return DeviceMetadata.gather(includeVendorIdentifier: includeVendorIdentifier)
    }

    public static func configure(
        apiKey: String,
        baseURL: URL,
        session: URLSession = .shared,
        defaultMetadata: [String: String] = [:],
        includeAutomaticMetadata: Bool = true,
        includeVendorIdentifier: Bool = false,
        identity: CustomerIdentity? = nil,
        identityKeySyncPolicy: IdentityKeySyncPolicy = .iCloud
    ) {
        lock.lock()
        defer { lock.unlock() }

        Self.identityKeySyncPolicy = identityKeySyncPolicy
        configuration = Configuration(
            apiKey: apiKey,
            baseURL: baseURL,
            session: session,
            defaultMetadata: defaultMetadata,
            includeAutomaticMetadata: includeAutomaticMetadata,
            includeVendorIdentifier: includeVendorIdentifier,
            identity: identity ?? configuration?.identity,
            signingKey: configuration?.signingKey
        )
    }

    public static var identityKeySyncEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }

        return IdentityKeySync.effectiveSyncEnabled(
            policy: identityKeySyncPolicy,
            storedPreference: IdentityKeySync.storedPreference()
        )
    }

    public static func setIdentityKeySyncEnabled(_ enabled: Bool) throws {
        lock.lock()
        let policy = identityKeySyncPolicy
        guard IdentityKeySync.isRuntimeConfigurable(policy) else {
            lock.unlock()
            throw FeedbackSDKError.identitySyncNotConfigurable
        }

        let currentEnabled = IdentityKeySync.effectiveSyncEnabled(
            policy: policy,
            storedPreference: IdentityKeySync.storedPreference()
        )
        guard enabled != currentEnabled else {
            lock.unlock()
            return
        }

        IdentityKeySync.setStoredPreference(enabled)

        guard let config = configuration,
              let identity = config.identity,
              let signingKey = config.signingKey
        else {
            lock.unlock()
            return
        }

        let storedIdentity = IdentityStorage.StoredIdentity(
            id: identity.id,
            externalUserId: identity.externalUserId,
            label: identity.label,
            privateKey: signingKey.rawRepresentation
        )
        lock.unlock()

        try IdentityStorage.migrate(
            storedIdentity,
            fromSynchronizable: currentEnabled,
            toSynchronizable: enabled
        )
    }

    public static func ensureIdentity(
        externalUserId: String? = nil,
        label: String? = nil
    ) async throws -> CustomerIdentity {
        loadStoredIdentityIfNeeded()
        let config = try currentConfiguration()
        if let identity = config.identity, config.signingKey != nil {
            return identity
        }

        return try await registerIdentity(externalUserId: externalUserId, label: label)
    }

    public static func registerIdentity(
        externalUserId: String? = nil,
        label: String? = nil
    ) async throws -> CustomerIdentity {
        let config = try currentConfiguration()
        let privateKey = Curve25519.Signing.PrivateKey.generate()
        let requestBody = RegisterCustomerIdentityRequest(
            publicKey: privateKey.publicKeyBase64URL,
            externalUserId: externalUserId,
            label: label
        )

        let body = try JSONEncoder.feedback.encode(requestBody)
        let url = config.baseURL.appendingPathComponent("api/v1/customer-identities")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = body

        let (data, response) = try await config.session.data(for: request)
        try validate(response: response, data: data)
        let registered = try JSONDecoder.feedback.decode(RegisterCustomerIdentityResponse.self, from: data)

        let identity = CustomerIdentity(
            id: registered.id,
            externalUserId: registered.externalUserId,
            label: registered.label
        )

        try IdentityStorage.save(
            IdentityStorage.StoredIdentity(
                id: identity.id,
                externalUserId: identity.externalUserId,
                label: identity.label,
                privateKey: privateKey.rawRepresentation
            ),
            synchronizable: effectiveIdentityKeySyncEnabled()
        )

        setConfiguration(
            Configuration(
                apiKey: config.apiKey,
                baseURL: config.baseURL,
                session: config.session,
                defaultMetadata: config.defaultMetadata,
                includeAutomaticMetadata: config.includeAutomaticMetadata,
                includeVendorIdentifier: config.includeVendorIdentifier,
                identity: identity,
                signingKey: privateKey
            )
        )

        return identity
    }

    public static func submit(_ submission: FeedbackSubmission) async throws -> SubmitFeedbackResponse {
        loadStoredIdentityIfNeeded()
        let config = try currentConfiguration()
        let metadata = DeviceMetadata.merged(
            includeAutomatic: config.includeAutomaticMetadata,
            includeVendorIdentifier: config.includeVendorIdentifier,
            defaultMetadata: config.defaultMetadata,
            submissionMetadata: submission.metadata
        )

        var attachmentIds: [UUID]?
        if !submission.attachments.isEmpty {
            attachmentIds = try await AttachmentUploader.upload(
                files: submission.attachments,
                ticketId: nil,
                baseURL: config.baseURL,
                session: config.session,
                signedRequestData: signedRequestData
            )
        }

        let requestBody = SubmitFeedbackRequest(
            type: submission.type,
            title: submission.title,
            body: submission.body,
            metadata: metadata.isEmpty ? nil : metadata,
            externalUserId: submission.externalUserId,
            attachmentIds: attachmentIds
        )

        let body = try JSONEncoder.feedback.encode(requestBody)
        let url = config.baseURL.appendingPathComponent("api/v1/tickets")
        let sign = config.identity != nil
        let data = try await requestData(method: "POST", url: url, body: body, sign: sign)
        return try JSONDecoder.feedback.decode(SubmitFeedbackResponse.self, from: data)
    }

    public static func tickets(limit: Int = 50, offset: Int = 0) async throws -> ListTicketsResponse {
        let config = try currentConfiguration()
        var components = URLComponents(
            url: config.baseURL.appendingPathComponent("api/v1/tickets"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components.url else {
            throw FeedbackSDKError.invalidResponse
        }

        let data = try await signedRequestData(method: "GET", url: url, body: Data())
        return try JSONDecoder.feedback.decode(ListTicketsResponse.self, from: data)
    }

    public static func ticket(id: UUID) async throws -> Ticket {
        let config = try currentConfiguration()
        let url = config.baseURL
            .appendingPathComponent("api/v1/tickets")
            .appendingPathComponent(id.urlId)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "X-Api-Key")

        let (data, response) = try await config.session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.feedback.decode(Ticket.self, from: data)
    }

    public static func reply(
        ticketId: UUID,
        body: String,
        attachments: [AttachmentInput] = []
    ) async throws -> Ticket {
        let config = try currentConfiguration()

        var attachmentIds: [UUID]?
        if !attachments.isEmpty {
            attachmentIds = try await AttachmentUploader.upload(
                files: attachments,
                ticketId: ticketId,
                baseURL: config.baseURL,
                session: config.session,
                signedRequestData: signedRequestData
            )
        }

        let requestBody = AddCustomerMessageRequest(body: body, attachmentIds: attachmentIds)
        let bodyData = try JSONEncoder.feedback.encode(requestBody)
        let url = config.baseURL
            .appendingPathComponent("api/v1/tickets")
            .appendingPathComponent(ticketId.urlId)
            .appendingPathComponent("messages")

        let data = try await signedRequestData(method: "POST", url: url, body: bodyData)
        return try JSONDecoder.feedback.decode(Ticket.self, from: data)
    }

    private static func buildRequest(
        method: String,
        url: URL,
        body: Data,
        sign: Bool
    ) throws -> URLRequest {
        if sign {
            loadStoredIdentityIfNeeded()
        }

        let config = try currentConfiguration()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = body.isEmpty ? nil : body

        guard sign else {
            return request
        }

        guard let identity = config.identity, let signingKey = config.signingKey else {
            throw FeedbackSDKError.identityRequired
        }

        let signatureHeaders = try RequestSigning.signedHeaders(
            identity: identity,
            privateKey: signingKey,
            method: method,
            url: url,
            body: body
        )

        for (name, value) in signatureHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        return request
    }

    private static func signedRequestData(
        method: String,
        url: URL,
        body: Data
    ) async throws -> Data {
        try await requestData(method: method, url: url, body: body, sign: true)
    }

    private static func requestData(
        method: String,
        url: URL,
        body: Data,
        sign: Bool
    ) async throws -> Data {
        if sign {
            return try await withIdentityRecovery {
                try await performRequest(method: method, url: url, body: body, sign: true)
            }
        }

        return try await performRequest(method: method, url: url, body: body, sign: false)
    }

    private static func performRequest(
        method: String,
        url: URL,
        body: Data,
        sign: Bool
    ) async throws -> Data {
        let config = try currentConfiguration()
        let request = try buildRequest(method: method, url: url, body: body, sign: sign)
        let (data, response) = try await config.session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private static func withIdentityRecovery<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            guard CustomerIdentityRecovery.isUnrecognizedOnServer(error) else {
                throw error
            }

            try await reregisterIdentityAfterServerRejection()
            return try await operation()
        }
    }

    private static func reregisterIdentityAfterServerRejection() async throws {
        loadStoredIdentityIfNeeded()
        let config = try currentConfiguration()
        let externalUserId = config.identity?.externalUserId
        let label = config.identity?.label

        try clearStoredIdentity()
        _ = try await registerIdentity(externalUserId: externalUserId, label: label)
    }

    private static func clearStoredIdentity() throws {
        try IdentityStorage.deleteAll()

        lock.lock()
        defer { lock.unlock() }

        keychainLoadAttempted = false

        guard let config = configuration else { return }

        configuration = Configuration(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            session: config.session,
            defaultMetadata: config.defaultMetadata,
            includeAutomaticMetadata: config.includeAutomaticMetadata,
            includeVendorIdentifier: config.includeVendorIdentifier,
            identity: nil,
            signingKey: nil
        )
    }

    private static func setConfiguration(_ value: Configuration) {
        lock.lock()
        configuration = value
        if value.identity != nil, value.signingKey != nil {
            keychainLoadAttempted = true
        }
        lock.unlock()
    }

    private static func loadStoredIdentityIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !keychainLoadAttempted else { return }
        keychainLoadAttempted = true

        guard let config = configuration else { return }
        if config.identity != nil, config.signingKey != nil { return }

        guard let stored = try? IdentityStorage.load(
            effectiveSyncEnabled: effectiveIdentityKeySyncEnabled()
        ) else { return }
        guard let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: stored.privateKey) else {
            return
        }

        let identity = CustomerIdentity(
            id: stored.id,
            externalUserId: stored.externalUserId,
            label: stored.label
        )

        configuration = Configuration(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            session: config.session,
            defaultMetadata: config.defaultMetadata,
            includeAutomaticMetadata: config.includeAutomaticMetadata,
            includeVendorIdentifier: config.includeVendorIdentifier,
            identity: identity,
            signingKey: signingKey
        )
    }

    private static func effectiveIdentityKeySyncEnabled() -> Bool {
        IdentityKeySync.effectiveSyncEnabled(
            policy: identityKeySyncPolicy,
            storedPreference: IdentityKeySync.storedPreference()
        )
    }

    private static func currentConfiguration() throws -> Configuration {
        lock.lock()
        defer { lock.unlock() }
        guard let configuration else {
            throw FeedbackSDKError.notConfigured
        }
        return configuration
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackSDKError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorPayload.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw FeedbackSDKError.httpError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}

extension JSONEncoder {
    static let feedback: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}

extension JSONDecoder {
    static let feedback: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()
}
