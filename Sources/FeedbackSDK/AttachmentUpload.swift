import Foundation

/// MIME types accepted by the Feedback attachment upload API.
public enum AttachmentContentType: String, Sendable, CaseIterable, Codable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"
    case heic = "image/heic"
    case heif = "image/heif"
    case json = "application/json"
    case plainText = "text/plain"
    case csv = "text/csv"
    case gzip = "application/gzip"
    case zlib = "application/zlib"
    case octetStream = "application/octet-stream"

    /// Parses a MIME type string, ignoring parameters and normalizing case.
    public init?(mimeType: String) {
        let normalized =
            mimeType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? mimeType.lowercased()
        self.init(rawValue: normalized)
    }
}

public struct AttachmentInput: Sendable {
    public let filename: String
    public let data: Data
    public let contentType: AttachmentContentType

    public init(filename: String, data: Data, contentType: AttachmentContentType) {
        self.filename = filename
        self.data = data
        self.contentType = contentType
    }
}

enum AttachmentUploader {
    static func upload(
        files: [AttachmentInput],
        ticketId: UUID?,
        baseURL: URL,
        session: URLSession,
        signedRequestData: (_ method: String, _ url: URL, _ body: Data) async throws -> Data
    ) async throws -> [UUID] {
        var attachmentIds: [UUID] = []

        for file in files {
            let attachmentId = try await uploadSingle(
                file: file,
                ticketId: ticketId,
                baseURL: baseURL,
                session: session,
                signedRequestData: signedRequestData
            )
            attachmentIds.append(attachmentId)
        }

        return attachmentIds
    }

    private static func uploadSingle(
        file: AttachmentInput,
        ticketId: UUID?,
        baseURL: URL,
        session: URLSession,
        signedRequestData: (_ method: String, _ url: URL, _ body: Data) async throws -> Data
    ) async throws -> UUID {
        let initiateBody = try JSONEncoder.feedback.encode(
            InitiateAttachmentUploadRequest(
                filename: file.filename,
                contentType: file.contentType.rawValue,
                sizeBytes: file.data.count,
                ticketId: ticketId
            )
        )

        let initiateURL = attachmentURL(baseURL: baseURL, path: "attachments")
        let initiateData = try await signedRequestData("POST", initiateURL, initiateBody)

        let initiated = try JSONDecoder.feedback.decode(
            InitiateAttachmentUploadResponse.self,
            from: initiateData
        )

        var uploadRequest = URLRequest(url: initiated.uploadUrl)
        uploadRequest.httpMethod = "PUT"
        for (name, value) in initiated.uploadHeaders {
            uploadRequest.setValue(value, forHTTPHeaderField: name)
        }
        uploadRequest.httpBody = file.data

        let (_, uploadResponse) = try await session.data(for: uploadRequest)
        guard let httpUploadResponse = uploadResponse as? HTTPURLResponse,
              (200 ... 299).contains(httpUploadResponse.statusCode)
        else {
            throw FeedbackSDKError.invalidResponse
        }

        let completeURL = attachmentURL(
            baseURL: baseURL,
            path: "attachments/\(initiated.attachmentId.urlId)/complete"
        )
        let completeData = try await signedRequestData("POST", completeURL, Data())

        let completed = try JSONDecoder.feedback.decode(
            CompleteAttachmentUploadResponse.self,
            from: completeData
        )

        return completed.attachmentId
    }

    private static func attachmentURL(baseURL: URL, path: String) -> URL {
        baseURL.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent(path)
    }
}
