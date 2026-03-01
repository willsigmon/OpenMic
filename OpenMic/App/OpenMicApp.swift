import SwiftUI
import SwiftData

@main
struct OpenMicApp: App {
    @State private var appServices = AppServices()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
                .onAppear {
                    appServices.seedDefaultPersonaIfNeeded()
                }
                .task {
                    await appServices.bootstrap()
                }
        }
    }
}
