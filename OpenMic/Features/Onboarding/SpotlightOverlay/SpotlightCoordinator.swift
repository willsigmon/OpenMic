import SwiftUI

// MARK: - Spotlight Step

/// One step in the OpenMic spotlight tour
struct SpotlightStep: Identifiable, Equatable, Sendable {
    let id: SpotlightTargetID
    let title: String
    let description: String
}

// MARK: - Spotlight Tour

struct SpotlightTour: Identifiable, Sendable {
    let id: String
    let steps: [SpotlightStep]

    /// First-run tour covering the four key interaction surfaces
    static let firstRun = SpotlightTour(
        id: "first_run",
        steps: [
            SpotlightStep(
                id: .micButton,
                title: "Start Talking",
                description: "Tap to start a voice conversation."
            ),
            SpotlightStep(
                id: .providerBadge,
                title: "Switch AI Provider",
                description: "Switch AI providers here."
            ),
            SpotlightStep(
                id: .topicsTab,
                title: "Topics",
                description: "Browse conversation starters."
            ),
            SpotlightStep(
                id: .settingsTab,
                title: "Settings",
                description: "Add your API keys and customize voices."
            )
        ]
    )
}

// MARK: - Spotlight Coordinator View Model

@Observable
final class SpotlightCoordinatorViewModel {

    // MARK: - State

    private(set) var isActive: Bool = false
    private(set) var currentStepIndex: Int = 0
    private(set) var tour: SpotlightTour?

    private var onComplete: (() -> Void)?
    private var onSkip: (() -> Void)?

    // MARK: - Computed

    var currentStep: SpotlightStep? {
        guard let tour, currentStepIndex < tour.steps.count else { return nil }
        return tour.steps[currentStepIndex]
    }

    var totalSteps: Int { tour?.steps.count ?? 0 }
    var isLastStep: Bool { currentStepIndex == totalSteps - 1 }

    // MARK: - Public API

    func startTour(
        _ tour: SpotlightTour,
        onComplete: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil
    ) {
        self.tour = tour
        self.currentStepIndex = 0
        self.onComplete = onComplete
        self.onSkip = onSkip

        withAnimation(OpenMicTheme.Animation.bouncy) {
            self.isActive = true
        }
    }

    @MainActor
    func nextStep() {
        guard isActive, let tour else { return }

        if currentStepIndex < tour.steps.count - 1 {
            withAnimation(OpenMicTheme.Animation.springy) {
                currentStepIndex += 1
            }
            Haptics.select()
        } else {
            completeTour()
        }
    }

    @MainActor
    func skipTour() {
        guard isActive else { return }

        withAnimation(OpenMicTheme.Animation.fast) {
            isActive = false
        }
        Haptics.tap()
        onSkip?()
        scheduleCleanup()
    }

    @MainActor
    func completeTour() {
        guard isActive else { return }

        withAnimation(OpenMicTheme.Animation.fast) {
            isActive = false
        }
        Haptics.success()
        onComplete?()
        scheduleCleanup()
    }

    // MARK: - Private

    @MainActor
    private func scheduleCleanup() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.tour = nil
            self?.currentStepIndex = 0
            self?.onComplete = nil
            self?.onSkip = nil
        }
    }
}

// MARK: - Spotlight Coordinator View

struct SpotlightCoordinator<Content: View>: View {

    @State private var viewModel = SpotlightCoordinatorViewModel()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlayPreferenceValue(SpotlightPreferenceKey.self) { anchors in
                GeometryReader { geometry in
                    if viewModel.isActive,
                       let step = viewModel.currentStep,
                       let anchor = anchors[step.id] {
                        let rect = geometry[anchor]
                        SpotlightOverlay(
                            targetRect: rect,
                            containerSize: geometry.size,
                            title: step.title,
                            description: step.description,
                            currentStep: viewModel.currentStepIndex + 1,
                            totalSteps: viewModel.totalSteps,
                            onNext: { viewModel.nextStep() },
                            onSkip: { viewModel.skipTour() }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(OpenMicTheme.Animation.bouncy, value: viewModel.currentStepIndex)
                .animation(OpenMicTheme.Animation.bouncy, value: viewModel.isActive)
            }
            .environment(viewModel)
    }
}

// MARK: - View Extension

extension View {
    /// Wraps the view in a SpotlightCoordinator for feature onboarding.
    func spotlightCoordinator() -> some View {
        SpotlightCoordinator { self }
    }
}

// MARK: - Environment Key

private struct SpotlightCoordinatorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: SpotlightCoordinatorViewModel? = nil
}

extension EnvironmentValues {
    var spotlightCoordinator: SpotlightCoordinatorViewModel? {
        get { self[SpotlightCoordinatorKey.self] }
        set { self[SpotlightCoordinatorKey.self] = newValue }
    }
}
