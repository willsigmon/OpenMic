import SwiftUI
import SwiftData

@main
struct OpenMicApp: App {
    @State private var launchState: LaunchState = .loading

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch launchState {
        case .loading:
            ProgressView("Launching OpenMic…")
                .task {
                    await loadAppServicesIfNeeded()
                }
        case .ready(let appServices):
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
        case .failed(let message):
            AppLaunchFailureView(message: message)
        }
    }

    @MainActor
    private func loadAppServicesIfNeeded() async {
        guard case .loading = launchState else { return }

        do {
            let appServices = try AppServices.make()
            appServices.seedDefaultPersonaIfNeeded()
            launchState = .ready(appServices)
            await appServices.bootstrap()
        } catch {
            launchState = .failed(error.localizedDescription)
        }
    }
}

private enum LaunchState {
    case loading
    case ready(AppServices)
    case failed(String)
}

private struct AppLaunchFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("OpenMic couldn't launch")
                .font(.title3.bold())
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
