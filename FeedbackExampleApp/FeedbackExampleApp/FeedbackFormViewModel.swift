import FeedbackSDK
import Foundation

@MainActor
final class FeedbackFormViewModel: ObservableObject {
    @Published var type: FeedbackType = .bug
    @Published var title = ""
    @Published var body = ""
    @Published var selectedAttachments: [AttachmentInput] = []
    @Published var isSubmitting = false
    @Published var submitResult: SubmitFeedbackResponse?
    @Published var submittedMetadata: [String: String]?
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    func addAttachments(_ attachments: [AttachmentInput]) {
        selectedAttachments = Array((selectedAttachments + attachments).prefix(5))
    }

    func removeAttachment(at index: Int) {
        guard selectedAttachments.indices.contains(index) else { return }
        selectedAttachments.remove(at: index)
    }

    func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil
        submitResult = nil
        submittedMetadata = nil

        defer { isSubmitting = false }

        await ensureIdentity()

        do {
            submitResult = try await FeedbackSDK.submit(
                FeedbackSubmission(
                    type: type,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                    attachments: selectedAttachments
                )
            )
            submittedMetadata = FeedbackSDK.automaticMetadata()
            clearFormFields()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearFormFields() {
        type = .bug
        title = ""
        body = ""
        selectedAttachments = []
    }

    private func ensureIdentity() async {
        do {
            _ = try await FeedbackSDK.ensureIdentity(label: "Feedback Example")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
