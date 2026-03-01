import SwiftUI

@main
struct OpenMicWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self)
    private var extensionDelegate

    @StateObject private var viewModel = WatchConversationViewModel()

    var body: some Scene {
        WindowGroup {
            WatchConversationView(viewModel: viewModel)
        }
    }
}
