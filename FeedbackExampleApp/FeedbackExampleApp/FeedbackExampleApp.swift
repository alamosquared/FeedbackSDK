import SwiftUI

enum AppWindow {
    static let myTickets = "my-tickets"
}

@main
struct FeedbackExampleApp: App {
    init() {
        FeedbackExampleAppSettings.configureSDK()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif

        #if os(macOS)
            WindowGroup("My Tickets", id: AppWindow.myTickets) {
                MyTicketsView()
            }
            .defaultSize(width: 960, height: 640)
        #endif
    }
}
