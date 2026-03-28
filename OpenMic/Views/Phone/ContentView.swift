import SwiftUI

struct ContentView: View {
    @Environment(AppServices.self) private var appServices

    var body: some View {
        if appServices.isOnboardingComplete {
            MainTabView()
                .accessibilityIdentifier(AppAccessibilityID.rootContent)
        } else {
            OnboardingContainerView()
                .accessibilityIdentifier(AppAccessibilityID.rootOnboarding)
        }
    }
}
