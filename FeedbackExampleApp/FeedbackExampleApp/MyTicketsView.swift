import FeedbackSDK
import SwiftUI

struct MyTicketsView: View {
    @StateObject private var viewModel = MyTicketsViewModel()
    #if os(macOS)
        @State private var selectedTicketId: UUID?
    #endif

    var body: some View {
        #if os(macOS)
            macBody
        #else
            iosBody
        #endif
    }

    #if os(macOS)
        private var macBody: some View {
            NavigationSplitView {
                ticketSidebar
            } detail: {
                ticketDetailPane
            }
            .frame(minWidth: 720, minHeight: 480)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
            }
            .task {
                if !viewModel.identityRegistered {
                    await viewModel.bootstrap()
                }
            }
            .onChange(of: viewModel.tickets.count) { _ in
                guard selectedTicketId == nil else { return }
                selectedTicketId = viewModel.tickets.first?.id
            }
            .overlay(alignment: .bottom) {
                errorBanner
            }
        }

        private var ticketSidebar: some View {
            Group {
                if viewModel.isLoadingList && viewModel.tickets.isEmpty {
                    ProgressView("Loading tickets…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tickets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No tickets yet")
                            .font(.headline)
                        Text("Submit feedback from the home window to create your first ticket.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(viewModel.tickets, selection: $selectedTicketId) { ticket in
                        ticketRow(ticket)
                            .tag(ticket.id)
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle("My tickets")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        }

        @ViewBuilder
        private var ticketDetailPane: some View {
            if let selectedTicketId {
                TicketDetailView(viewModel: viewModel, ticketId: selectedTicketId)
            } else {
                Text("Select a ticket")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    #endif

    private var iosBody: some View {
        ticketListContent
            .navigationTitle("My tickets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
            }
            .task {
                if !viewModel.identityRegistered {
                    await viewModel.bootstrap()
                }
            }
            .refreshable {
                await viewModel.loadTickets()
            }
            .overlay(alignment: .bottom) {
                errorBanner
            }
    }

    @ViewBuilder
    private var ticketListContent: some View {
        Group {
            if viewModel.isLoadingList && viewModel.tickets.isEmpty {
                ProgressView("Loading tickets…")
            } else if viewModel.tickets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No tickets yet")
                        .font(.headline)
                    Text("Submit feedback from the home screen to create your first ticket.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(viewModel.tickets) { ticket in
                    NavigationLink {
                        TicketDetailView(viewModel: viewModel, ticketId: ticket.id)
                    } label: {
                        ticketRow(ticket)
                    }
                }
            }
        }
    }

    private func ticketRow(_ ticket: TicketSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title)
                .font(.headline)
            Text(ticket.bodyPreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(statusLabel(ticket.status))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.loadTickets() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoadingList)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
    }

    private func statusLabel(_ status: TicketStatus) -> String {
        switch status {
        case .open: "Open"
        case .inProgress: "In progress"
        case .waitingOnCustomer: "Waiting on you"
        case .resolved: "Resolved"
        case .closed: "Closed"
        }
    }
}

struct TicketDetailView: View {
    @ObservedObject var viewModel: MyTicketsViewModel
    let ticketId: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoadingTicket && viewModel.selectedTicket?.id != ticketId {
                    ProgressView("Loading ticket…")
                } else if let ticket = viewModel.selectedTicket, ticket.id == ticketId {
                    Text(ticket.title)
                        .font(.title2)
                        .bold()

                    Text(statusLabel(ticket.status))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    ForEach(ticket.messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(messageAuthorLabel(message))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(message.body)
                        }
                        .padding(.vertical, 4)
                    }

                    if ticketAllowsCustomerMessages(ticket.status) {
                        Divider()

                        Text("Add message")
                            .font(.headline)

                        TextEditor(text: $viewModel.replyBody)
                            .frame(minHeight: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                            )

                        AttachmentPickerButton(title: "Attach screenshot") { attachments in
                            viewModel.addReplyAttachments(attachments)
                        }
                        .disabled(viewModel.isReplying)

                        SelectedAttachmentsList(attachments: viewModel.replyAttachments) { index in
                            viewModel.removeReplyAttachment(at: index)
                        }

                        Button {
                            Task { await viewModel.sendReply() }
                        } label: {
                            if viewModel.isReplying {
                                HStack {
                                    ProgressView()
                                    Text("Sending…")
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Text("Send message")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canReply)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Ticket")
        .task(id: ticketId) {
            await viewModel.loadTicket(id: ticketId)
        }
    }

    private func statusLabel(_ status: TicketStatus) -> String {
        switch status {
        case .open: "Open"
        case .inProgress: "In progress"
        case .waitingOnCustomer: "Waiting on you"
        case .resolved: "Resolved"
        case .closed: "Closed"
        }
    }

    private func messageAuthorLabel(_ message: Message) -> String {
        switch message.author {
        case .customer: "You"
        case .agent:
            if let name = message.agentDisplayName {
                "Agent · \(name)"
            } else {
                "Agent"
            }
        case .system: "System"
        }
    }
}
