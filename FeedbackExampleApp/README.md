# Feedback Example App

SwiftUI multiplatform example app that submits feedback through FeedbackSDK (local package at the repository root) against a Feedback gateway.

## Prerequisites

- Xcode with Swift 5.9+
- A Feedback gateway base URL and a project API key

## Run

1. Open [`FeedbackExampleApp.xcodeproj`](FeedbackExampleApp.xcodeproj) in Xcode.
2. Select **My Mac** or an **iOS Simulator** as the run destination.
3. Press **Run** (⌘R).

The app pre-fills settings for a local gateway:

| Setting  | Default                 |
| -------- | ----------------------- |
| API key  | `pk_dev_local`          |
| Base URL | `http://localhost:8070` |

Use the gear icon to change these for your environment.

## What it demonstrates

1. **Configure** — `FeedbackSDK.configure(apiKey:baseURL:defaultMetadata:identityKeySyncPolicy:)` on launch (re-applied after settings changes). By default the signing key syncs via iCloud Keychain; the example app uses `.userConfigurable(defaultSyncs: true)` so you can toggle sync in Settings.
2. **Identity** — `FeedbackSDK.ensureIdentity()` registers an Ed25519 signing key (stored in Keychain) for signed requests. With iCloud Keychain enabled on the device, the same identity can sync across your Apple devices.
3. **Submit** — form posts a `FeedbackSubmission` via `FeedbackSDK.submit(_:)` (signed when identity is present).
4. **My tickets** — lists prior tickets via `FeedbackSDK.tickets()` and supports customer replies with `FeedbackSDK.reply(ticketId:body:)`.
5. **Fetch** — optional **View ticket** calls `FeedbackSDK.ticket(id:)` with the returned ticket ID.
6. **Identity sync** — Settings includes **Sync identity across devices**, which calls `FeedbackSDK.setIdentityKeySyncEnabled(_:)` when the SDK is configured with `.userConfigurable`.

### Identity key sync policies

| Policy                             | Use when                                                   |
| ---------------------------------- | ---------------------------------------------------------- |
| `.iCloud` (default)                | Ticket history should follow the user across Apple devices |
| `.deviceOnly`                      | Identity must stay on this device only                     |
| `.userConfigurable(defaultSyncs:)` | You expose a privacy toggle in your app settings           |

Submitted tickets appear in your Feedback agent dashboard.

## Physical iOS device

The simulator can reach `http://localhost:8070` directly (ATS exception for `localhost` is in `Info.plist`). On a physical device, open **Settings** in the app and set the base URL to your Mac's LAN address, e.g. `http://192.168.1.10:8070`.

## Troubleshooting

| Symptom                               | Likely cause                                                           |
| ------------------------------------- | ---------------------------------------------------------------------- |
| Connection failed / could not connect | Gateway not reachable — check base URL and that the gateway is running |
| HTTP 401                              | Invalid API key — use a valid project key from your Feedback dashboard |
| HTTP 403                              | Organization suspended or archived                                     |
| FeedbackSDK is not configured         | Base URL in Settings is empty or invalid                               |

## Project layout

```
FeedbackExampleApp/
  FeedbackExampleApp.swift          App entry + SDK configure
  ContentView.swift                 Feedback form and results
  FeedbackFormViewModel.swift       Submit / fetch logic
  MyTicketsView.swift               Ticket list and reply UI
  MyTicketsViewModel.swift          Identity bootstrap + list/reply
  SettingsView.swift                API key and base URL
  FeedbackExampleAppSettings.swift  UserDefaults + configure helper
  Info.plist                        iOS ATS localhost exception
```

iCloud Keychain sync requires the user to have iCloud Keychain enabled in system settings; the SDK sets the Keychain synchronizable attribute but cannot force sync.
