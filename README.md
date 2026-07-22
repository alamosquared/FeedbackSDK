# FeedbackSDK

Swift Package for iOS and macOS apps that submit customer feedback to a [Feedback](https://github.com/kalahari/feedback) gateway.

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package dependency in Xcode (**File → Add Package Dependencies…**) or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alamosquared/FeedbackSDK.git", from: "0.1.0"),
],
```

Then add the `FeedbackSDK` product to your target.

### Local development (monorepo)

When working inside the Feedback monorepo, depend on the package path `sdk/FeedbackSDK` (the example app already does this).

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

## License

MIT — see [LICENSE](LICENSE).
