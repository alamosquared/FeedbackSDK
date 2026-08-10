# FeedbackSDK

Swift Package for iOS and macOS apps that submit customer feedback to a Feedback gateway.

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package dependency in Xcode (**File → Add Package Dependencies…**) or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alamosquared/FeedbackSDK.git", from: "0.2.0"),
],
```

Then add the `FeedbackSDK` product to your target.

## Usage

```swift
import FeedbackSDK

FeedbackSDK.configure(
    apiKey: "pk_your_project_key",
    baseURL: URL(string: "https://feedback.example.com")!
)

// Optional: override or extend automatic metadata (platform, os, deviceModel,
// locale, bundleId, appVersion, appBuild)
FeedbackSDK.configure(
    apiKey: "pk_your_project_key",
    baseURL: URL(string: "https://feedback.example.com")!,
    defaultMetadata: ["environment": "staging"],
    includeAutomaticMetadata: true // default; set false to send only defaultMetadata
)

// Register a device identity (Ed25519 key in Keychain) for signed requests
_ = try await FeedbackSDK.ensureIdentity(label: "My App")

let response = try await FeedbackSDK.submit(
    FeedbackSubmission(
        type: .bug,
        title: "Crash on launch",
        body: "The app closes immediately after the splash screen.",
        metadata: ["screen": "Settings"] // per-submission overrides win
    )
)

let tickets = try await FeedbackSDK.tickets()
let ticket = try await FeedbackSDK.ticket(id: response.ticketId)
_ = try await FeedbackSDK.reply(ticketId: ticket.id, body: "More details…")
```

### Identity key sync

By default the signing key syncs via iCloud Keychain (`.iCloud`). Use `.deviceOnly` to keep it local, or `.userConfigurable(defaultSyncs:)` when you expose a privacy toggle:

```swift
FeedbackSDK.configure(
    apiKey: "pk_your_project_key",
    baseURL: URL(string: "https://feedback.example.com")!,
    identityKeySyncPolicy: .userConfigurable(defaultSyncs: true)
)

try FeedbackSDK.setIdentityKeySyncEnabled(false)
```

### Attachments

Uploads must use an allowlisted MIME type via `AttachmentContentType`:

```swift
let attachment = AttachmentInput(
    filename: "diagnostics.json.zlib",
    data: compressedData,
    contentType: .octetStream // or .json, .gzip, .png, …
)

_ = try await FeedbackSDK.submit(
    FeedbackSubmission(
        type: .bug,
        title: "Diagnostics attached",
        body: "See attached payload.",
        attachments: [attachment]
    )
)
```

`AttachmentContentType.allCases` lists every accepted type. Use `AttachmentContentType(mimeType:)` to parse a MIME string (parameters are ignored).

## Example

A SwiftUI multiplatform sample app lives in [`FeedbackExampleApp/`](FeedbackExampleApp/). Open `FeedbackExampleApp.xcodeproj` in Xcode — it depends on the local package at the repository root. See that folder’s README for setup (API key, gateway base URL, and identity sync).

## License

MIT — see [LICENSE](LICENSE).
