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
                .accessibilityIdentifier(AppAccessibilityID.rootLoading)
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
            Haptics.startEngine()
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
        VStack(spacing: OpenMicTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(OpenMicTheme.Typography.heroTitle)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("OpenMic couldn't launch")
                .font(OpenMicTheme.Typography.title)
            Text(message)
                .font(OpenMicTheme.Typography.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OpenMic couldn't launch. \(message)")
        .accessibilityIdentifier(AppAccessibilityID.rootFailure)
    }
}
