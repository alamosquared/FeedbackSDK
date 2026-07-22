import Foundation

public struct CustomerIdentity: Codable, Sendable, Identifiable {
    public let id: UUID
    public let externalUserId: String?
    public let label: String?

    public init(id: UUID, externalUserId: String? = nil, label: String? = nil) {
        self.id = id
        self.externalUserId = externalUserId
        self.label = label
    }
}

public struct TicketSummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: FeedbackType
    public let title: String
    public let bodyPreview: String
    public let status: TicketStatus
    public let externalUserId: String?
    public let messageCount: Int
    public let createdAt: Date
    public let updatedAt: Date
}

public struct ListTicketsResponse: Codable, Sendable {
    public let items: [TicketSummary]
    public let total: Int
    public let limit: Int
    public let offset: Int
}

struct RegisterCustomerIdentityRequest: Encodable {
    let publicKey: String
    let externalUserId: String?
    let label: String?
}

struct RegisterCustomerIdentityResponse: Decodable {
    let id: UUID
    let externalUserId: String?
    let label: String?
    let createdAt: Date
}

struct AddCustomerMessageRequest: Encodable {
    let body: String
    let attachmentIds: [UUID]?
}
