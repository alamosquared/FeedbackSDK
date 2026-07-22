import FeedbackSDK
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FeedbackFormViewModel()
    @State private var showSettings = false
    #if os(macOS)
        @Environment(\.openWindow) private var openWindow
        @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    #else
        @State private var selectedTab: IOSAppTab = .poem
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
            NavigationSplitView(columnVisibility: $sidebarVisibility) {
                feedbackSidebar
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
            } detail: {
                mainContent
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 720, minHeight: 560)
        }

        private var mainContent: some View {
            ScrollView {
                DemoContentView()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Jabberwocky")
        }

        private var feedbackSidebar: some View {
            VStack(spacing: 0) {
                ScrollView {
                    feedbackFormContent
                        .padding()
                }

                Divider()

                HStack {
                    Button("My tickets") {
                        openWindow(id: AppWindow.myTickets)
                    }
                    Spacer()
                    settingsButton
                }
                .padding()
            }
            .navigationTitle("Feedback")
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    #else
    private var iosBody: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ScrollView {
                    DemoContentView()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Jabberwocky")
            }
            .tabItem {
                Label("Poem", systemImage: "text.book.closed")
            }
            .tag(IOSAppTab.poem)

            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        feedbackFormContent

                        NavigationLink {
                            MyTicketsView()
                        } label: {
                            Text("My tickets")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Feedback")
            }
            .tabItem {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(IOSAppTab.feedback)

            SettingsView(showsDismissButton: false)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(IOSAppTab.settings)
        }
    }
    #endif

    private var feedbackFormContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            feedbackSection
            submitSection

            if let result = viewModel.submitResult {
                submittedSection(result)
            }

            if let errorMessage = viewModel.errorMessage {
                errorSection(errorMessage)
            }
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
    }

    private var feedbackSection: some View {
        sectionCard("Feedback") {
            Picker("Type", selection: $viewModel.type) {
                Text("Bug").tag(FeedbackType.bug)
                Text("Feature").tag(FeedbackType.feature)
                Text("Question").tag(FeedbackType.question)
                Text("Other").tag(FeedbackType.other)
            }
            #if os(macOS)
                .pickerStyle(.menu)
            #endif

            TextField("Title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isSubmitting)

            ZStack(alignment: .topLeading) {
                if viewModel.body.isEmpty {
                    Text("Description")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $viewModel.body)
                    .frame(minHeight: 120)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )
                    .disabled(viewModel.isSubmitting)
            }

            AttachmentPickerButton(title: "Attach screenshot") { attachments in
                viewModel.addAttachments(attachments)
            }
            .disabled(viewModel.isSubmitting)

            SelectedAttachmentsList(attachments: viewModel.selectedAttachments) { index in
                viewModel.removeAttachment(at: index)
            }
        }
    }

    private var submitSection: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            if viewModel.isSubmitting {
                HStack {
                    ProgressView()
                    Text("Submitting…")
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Submit feedback")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSubmit)
    }

    private func submittedSection(_ result: SubmitFeedbackResponse) -> some View {
        sectionCard("Submitted") {
            labelRow("Ticket ID", value: result.ticketId.uuidString)
            labelRow("Status", value: statusLabel(result.status))

            if let metadata = viewModel.submittedMetadata, !metadata.isEmpty {
                Divider()

                Text("Metadata")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(metadata.keys.sorted(), id: \.self) { key in
                    labelRow(key, value: metadata[key] ?? "")
                }
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        sectionCard("Error") {
            Text(message)
                .foregroundStyle(.red)
        }
    }

    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var sectionBackground: some View {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #else
            Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    private func labelRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusLabel(_ status: TicketStatus) -> String {
        switch status {
        case .open: "Open"
        case .inProgress: "In progress"
        case .waitingOnCustomer: "Waiting on customer"
        case .resolved: "Resolved"
        case .closed: "Closed"
        }
    }

}

#if os(iOS)
    private enum IOSAppTab {
        case poem
        case feedback
        case settings
    }
#endif

#Preview {
    ContentView()
}
