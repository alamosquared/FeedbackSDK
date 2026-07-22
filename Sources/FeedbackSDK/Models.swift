import Foundation

public enum IdentityKeySyncPolicy: Sendable, Equatable {
    case iCloud
    case deviceOnly
    case userConfigurable(defaultSyncs: Bool = true)
}

public enum FeedbackType: String, Codable, Sendable {
    case bug
    case feature
    case question
    case other
}

public enum TicketStatus: String, Codable, Sendable {
    case open
    case inProgress = "in_progress"
    case waitingOnCustomer = "waiting_on_customer"
    case resolved
    case closed
}

public enum MessageAuthor: String, Codable, Sendable {
    case customer
    case agent
    case system
}

public struct FeedbackSubmission: Sendable {
    public let type: FeedbackType
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public let externalUserId: String?
    public let attachments: [AttachmentInput]

    public init(
        type: FeedbackType,
        title: String,
        body: String,
        metadata: [String: String] = [:],
        externalUserId: String? = nil,
        attachments: [AttachmentInput] = []
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.metadata = metadata
        self.externalUserId = externalUserId
        self.attachments = attachments
    }
}

public struct SubmitFeedbackResponse: Codable, Sendable {
    public let ticketId: UUID
    public let status: TicketStatus
}

public struct Attachment: Codable, Sendable, Identifiable {
    public let id: UUID
    public let filename: String
    public let contentType: String
    public let sizeBytes: Int
    public let createdAt: Date
}

public struct Message: Codable, Sendable, Identifiable {
    public let id: UUID
    public let body: String
    public let author: MessageAuthor
    public let agentId: UUID?
    public let agentDisplayName: String?
    public let createdAt: Date
    public let attachments: [Attachment]

    public init(
        id: UUID,
        body: String,
        author: MessageAuthor,
        agentId: UUID?,
        agentDisplayName: String?,
        createdAt: Date,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.body = body
        self.author = author
        self.agentId = agentId
        self.agentDisplayName = agentDisplayName
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

public struct Ticket: Codable, Sendable, Identifiable {
    public let id: UUID
    public let projectId: UUID
    public let type: FeedbackType
    public let title: String
    public let body: String
    public let status: TicketStatus
    public let externalUserId: String?
    public let customerIdentityId: UUID?
    public let metadata: [String: String]?
    public let createdAt: Date
    public let updatedAt: Date
    public let messages: [Message]
}

public enum FeedbackSDKError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidResponse
    case identityRequired
    case identitySyncNotConfigurable
    case keychainError(OSStatus)
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "FeedbackSDK is not configured. Call FeedbackSDK.configure(apiKey:baseURL:) first."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .identityRequired:
            return "A registered customer identity is required. Call FeedbackSDK.registerIdentity() first."
        case .identitySyncNotConfigurable:
            return "Identity key sync cannot be changed unless FeedbackSDK was configured with .userConfigurable."
        case let .keychainError(status):
            return "Keychain error (OSStatus \(status))."
        case let .httpError(statusCode, message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}

struct SubmitFeedbackRequest: Encodable {
    let type: FeedbackType
    let title: String
    let body: String
    let metadata: [String: String]?
    let externalUserId: String?
    let attachmentIds: [UUID]?
}

struct InitiateAttachmentUploadRequest: Encodable {
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let ticketId: UUID?
}

struct InitiateAttachmentUploadResponse: Decodable {
    let attachmentId: UUID
    let uploadUrl: URL
    let uploadHeaders: [String: String]
    let expiresAt: Date
}

struct CompleteAttachmentUploadResponse: Decodable {
    let attachmentId: UUID
    let status: String
    let filename: String
    let contentType: String
    let sizeBytes: Int
}

struct ErrorPayload: Decodable {
    let error: String
}
