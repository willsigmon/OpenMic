import Foundation
import SwiftUI
import Speech
import AVFoundation

@Observable
@MainActor
final class OnboardingViewModel {
    private let appServices: AppServices

    var currentStep: OnboardingStep = .welcome
    var selectedProvider: AIProviderType = .openAI
    var apiKey = ""
    var hasMicPermission = false
    var hasSpeechPermission = false
    var showPaywall = false

    var effectiveTier: SubscriptionTier {
        appServices.effectiveTier
    }

    init(appServices: AppServices) {
        self.appServices = appServices
    }

    func requestPermissions() {
        Task {
            hasMicPermission = await AVAudioApplication.requestRecordPermission()
            let status = await Self.requestSpeechAuthorization()
            hasSpeechPermission = status == .authorized
        }
    }

    /// Must be nonisolated so the callback closure doesn't inherit MainActor isolation.
    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        Task {
            try? await appServices.keychainManager.saveAPIKey(
                for: selectedProvider,
                key: trimmedKey
            )
        }
    }

    /// Try a free voice interaction during onboarding (system TTS, no API cost)
    func tryFreeVoice() {
        // Trigger a quick system TTS demo
        let utterance = AVSpeechUtterance(string: "Hi there! I'm your AI copilot for the road. Ask me anything.")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        AVSpeechSynthesizer().speak(utterance)
    }

    func completeOnboarding() {
        // Only save API key if in BYOK path
        if currentStep == .apiKey || !apiKey.isEmpty {
            saveAPIKey()
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        }
        appServices.completeOnboarding()
    }

    func advance() {
        switch currentStep {
        case .welcome: currentStep = .permissions
        case .permissions: currentStep = .tryItFree
        case .tryItFree: currentStep = .voicePreview
        case .voicePreview: currentStep = .signIn
        case .signIn: currentStep = .ready
        case .apiKey: currentStep = .ready
        case .ready: completeOnboarding()
        }
    }

    /// Skip directly to ready (for users who just want to start free)
    func skipToReady() {
        currentStep = .ready
    }

    /// Jump to BYOK API key step (from Settings → Advanced)
    func goToAPIKeyStep() {
        currentStep = .apiKey
    }

    func goBack() {
        switch currentStep {
        case .welcome: break
        case .permissions: currentStep = .welcome
        case .tryItFree: currentStep = .permissions
        case .voicePreview: currentStep = .tryItFree
        case .signIn: currentStep = .voicePreview
        case .apiKey: currentStep = .permissions
        case .ready: currentStep = .signIn
        }
    }
}

enum OnboardingStep: CaseIterable {
    case welcome
    case permissions
    case tryItFree
    case voicePreview
    case signIn
    case apiKey
    case ready
}
