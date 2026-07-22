import FeedbackSDK
import Foundation

@MainActor
final class MyTicketsViewModel: ObservableObject {
    @Published var tickets: [TicketSummary] = []
    @Published var selectedTicket: Ticket?
    @Published var replyBody = ""
    @Published var replyAttachments: [AttachmentInput] = []
    @Published var isLoadingList = false
    @Published var isLoadingTicket = false
    @Published var isReplying = false
    @Published var identityRegistered = false
    @Published var errorMessage: String?

    func bootstrap() async {
        do {
            _ = try await FeedbackSDK.ensureIdentity(label: "Feedback Example")
            identityRegistered = true
            await loadTickets()
        } catch let error as FeedbackSDKError {
            if case .httpError(let statusCode, _) = error, statusCode == 401 {
                errorMessage = "Invalid API key. Check Settings."
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTickets() async {
        isLoadingList = true
        errorMessage = nil

        defer { isLoadingList = false }

        do {
            let response = try await FeedbackSDK.tickets()
            tickets = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTicket(id: UUID) async {
        isLoadingTicket = true
        errorMessage = nil
        replyBody = ""
        replyAttachments = []

        defer { isLoadingTicket = false }

        do {
            selectedTicket = try await FeedbackSDK.ticket(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canReply: Bool {
        guard let ticket = selectedTicket else { return false }
        return ticketAllowsCustomerMessages(ticket.status)
            && !replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isReplying
    }

    func addReplyAttachments(_ attachments: [AttachmentInput]) {
        replyAttachments = Array((replyAttachments + attachments).prefix(5))
    }

    func removeReplyAttachment(at index: Int) {
        guard replyAttachments.indices.contains(index) else { return }
        replyAttachments.remove(at: index)
    }

    func sendReply() async {
        guard let ticketId = selectedTicket?.id, canReply else { return }

        isReplying = true
        errorMessage = nil

        defer { isReplying = false }

        do {
            selectedTicket = try await FeedbackSDK.reply(
                ticketId: ticketId,
                body: replyBody.trimmingCharacters(in: .whitespacesAndNewlines),
                attachments: replyAttachments
            )
            replyBody = ""
            replyAttachments = []
            await loadTickets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

func ticketAllowsCustomerMessages(_ status: TicketStatus) -> Bool {
    switch status {
    case .open, .inProgress, .waitingOnCustomer:
        true
    case .resolved, .closed:
        false
    }
}
