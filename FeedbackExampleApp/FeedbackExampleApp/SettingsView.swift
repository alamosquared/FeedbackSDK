import FeedbackSDK
import SwiftUI

struct SettingsView: View {
    var showsDismissButton = true

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = FeedbackExampleAppSettings.apiKey
    @State private var baseURLString = FeedbackExampleAppSettings.baseURLString
    @State private var identitySyncEnabled = FeedbackSDK.identityKeySyncEnabled
    @State private var validationMessage: String?
    @State private var syncErrorMessage: String?

    var body: some View {
        Group {
            #if os(macOS)
                NavigationStack {
                    settingsForm
                }
            #else
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        settingsForm
                    }
                } else {
                    NavigationView {
                        settingsForm
                    }
                }
            #endif
        }
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 260)
        #endif
    }

    @ViewBuilder
    private var settingsForm: some View {
        let form = Form {
            Section {
                apiKeyField
                baseURLField
                footerText
            }

            Section {
                Toggle("Sync identity across devices", isOn: $identitySyncEnabled)
                    .onChange(of: identitySyncEnabled) { newValue in
                        updateIdentitySyncEnabled(newValue)
                    }
                Text(
                    "When enabled, your feedback identity and ticket history can follow you across Apple devices via iCloud Keychain."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }

            if let syncErrorMessage {
                Section {
                    Text(syncErrorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        #if os(macOS)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        #endif
        .navigationTitle("Settings")

        if showsDismissButton {
            form.toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        } else {
            form.toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private var apiKeyField: some View {
        #if os(iOS)
            TextField("API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        #else
            TextField("API key", text: $apiKey)
        #endif
    }

    private var baseURLField: some View {
        #if os(iOS)
            TextField("Base URL", text: $baseURLString)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        #else
            TextField("Base URL", text: $baseURLString)
        #endif
    }

    private var footerText: some View {
        Text(
            "Defaults match local dev: pk_dev_local and http://localhost:8070. On a physical iOS device, use your Mac's LAN IP instead of localhost."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            validationMessage = "API key is required."
            return
        }

        guard URL(string: trimmedURL) != nil else {
            validationMessage = "Enter a valid base URL (e.g. http://localhost:8070)."
            return
        }

        FeedbackExampleAppSettings.apiKey = trimmedKey
        FeedbackExampleAppSettings.baseURLString = trimmedURL
        FeedbackExampleAppSettings.configureSDK()
        validationMessage = nil
        if showsDismissButton {
            dismiss()
        }
    }

    private func updateIdentitySyncEnabled(_ enabled: Bool) {
        do {
            try FeedbackSDK.setIdentityKeySyncEnabled(enabled)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = error.localizedDescription
            identitySyncEnabled = FeedbackSDK.identityKeySyncEnabled
        }
    }
}

#Preview {
    SettingsView()
}
