import Foundation

enum CustomerIdentityRecovery {
    static let unrecognizedServerMessages: Set<String> = [
        "Invalid customer identity",
        "Customer identity revoked",
    ]

    static func isUnrecognizedOnServer(_ error: Error) -> Bool {
        guard case let FeedbackSDKError.httpError(statusCode, message) = error else {
            return false
        }

        return statusCode == 401 && unrecognizedServerMessages.contains(message)
    }
}
