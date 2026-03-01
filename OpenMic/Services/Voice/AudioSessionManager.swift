import AVFoundation

enum TTSAudioRequirement {
    case speechSynthesizer  // AVSpeechSynthesizer needs .playAndRecord
    case audioPlayer        // AVAudioPlayer works with .playback
}

@MainActor
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private static let outputModeKey = "audioOutputMode"
    private let audioSession = AVAudioSession.sharedInstance()
    private var routeEnforcementTask: Task<Void, Never>?
    private(set) var isCarPlayActive = false

    private init() {}

    func configureForListening() throws {
        // When CarPlay is active, always use car-speaker routing
        if isCarPlayActive {
            try configureForCarPlay()
            return
        }

        let outputMode = preferredOutputMode
        let options = listeningCategoryOptions(for: outputMode)
        let mode = listeningMode(for: outputMode)

        try audioSession.setCategory(
            .playAndRecord,
            mode: mode,
            options: options
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        try applyPreferredInput(for: outputMode)
        try applyOutputOverride(for: outputMode)
        scheduleRouteEnforcement(for: outputMode)
    }

    func configureForSpeaking(_ requirement: TTSAudioRequirement = .audioPlayer) throws {
        routeEnforcementTask?.cancel()
        routeEnforcementTask = nil

        switch requirement {
        case .speechSynthesizer:
            // AVSpeechSynthesizer requires .playAndRecord to produce audio on
            // most iOS versions. .defaultToSpeaker routes to the loudspeaker,
            // .mixWithOthers prevents session conflicts.
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .duckOthers, .mixWithOthers]
            )

        case .audioPlayer:
            // AVAudioPlayer (ElevenLabs) works with plain .playback.
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
        }

        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Configure for CarPlay: force car-speaker routing regardless of stored preference.
    /// Sets `isCarPlayActive` so `configureForListening()` and `deactivate()` respect CarPlay mode.
    func configureForCarPlay() throws {
        isCarPlayActive = true
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .duckOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Clear CarPlay audio mode.
    func deactivateCarPlay() throws {
        isCarPlayActive = false
        try deactivate()
    }

    // Backward-compatible alias for existing call sites.
    func configureForVoiceChat() throws {
        try configureForListening()
    }

    func deactivate() throws {
        routeEnforcementTask?.cancel()
        routeEnforcementTask = nil
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    var preferredOutputMode: AudioOutputMode {
        guard
            let raw = UserDefaults.standard.string(forKey: Self.outputModeKey),
            let mode = AudioOutputMode(rawValue: raw)
        else {
            return .defaultMode
        }
        return mode
    }

    func setPreferredOutputMode(_ mode: AudioOutputMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.outputModeKey)
        switch audioSession.category {
        case .playAndRecord:
            try? configureForListening()
        case .playback:
            try? configureForSpeaking()
        default:
            break
        }
    }

    var currentOutputRouteName: String {
        audioSession.currentRoute.outputs.first?.portName ?? "Unknown"
    }

    var currentRouteSummary: String {
        let outputs = audioSession.currentRoute.outputs.map { output in
            "\(output.portName) (\(output.portType.rawValue))"
        }
        let inputs = audioSession.currentRoute.inputs.map { input in
            "\(input.portName) (\(input.portType.rawValue))"
        }
        return "Out: \(outputs.joined(separator: ", ")) • In: \(inputs.joined(separator: ", "))"
    }

    private func applyOutputOverride(for mode: AudioOutputMode) throws {
        switch mode {
        case .automatic:
            try audioSession.overrideOutputAudioPort(.none)
        case .speakerphone:
            try audioSession.overrideOutputAudioPort(.speaker)
        }
    }

    private func applyPreferredInput(for mode: AudioOutputMode) throws {
        switch mode {
        case .automatic:
            try audioSession.setPreferredInput(nil)
        case .speakerphone:
            try audioSession.setPreferredInput(nil)
        }
    }

    private func listeningCategoryOptions(for mode: AudioOutputMode) -> AVAudioSession.CategoryOptions {
        switch mode {
        case .automatic:
            return [
                .allowBluetoothHFP,
                .allowBluetoothA2DP,
                .duckOthers
            ]
        case .speakerphone:
            // No Bluetooth options — speakerphone means built-in speaker.
            return [
                .defaultToSpeaker,
                .duckOthers
            ]
        }
    }

    private func listeningMode(for mode: AudioOutputMode) -> AVAudioSession.Mode {
        switch mode {
        case .automatic:
            return .voiceChat
        case .speakerphone:
            return .default
        }
    }

    private func scheduleRouteEnforcement(for mode: AudioOutputMode) {
        routeEnforcementTask?.cancel()
        routeEnforcementTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            try? applyPreferredInput(for: mode)
            try? applyOutputOverride(for: mode)

            if mode == .speakerphone && !isUsingBuiltInSpeaker {
                try? audioSession.setCategory(
                    .playAndRecord,
                    mode: listeningMode(for: mode),
                    options: listeningCategoryOptions(for: mode)
                )
                try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                try? applyPreferredInput(for: mode)
                try? applyOutputOverride(for: mode)
            }
        }
    }

    private var isUsingBuiltInSpeaker: Bool {
        audioSession.currentRoute.outputs.contains { $0.portType == .builtInSpeaker }
    }

    var isBluetoothConnected: Bool {
        audioSession.currentRoute.outputs.contains { output in
            output.portType == .bluetoothA2DP
            || output.portType == .bluetoothHFP
            || output.portType == .bluetoothLE
        }
    }

    var sampleRate: Double {
        audioSession.sampleRate
    }

    func observeInterruptions(
        handler: @escaping @Sendable (AVAudioSession.InterruptionType) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { notification in
            guard let typeValue = notification.userInfo?[
                AVAudioSessionInterruptionTypeKey
            ] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            handler(type)
        }
    }

    func observeRouteChanges(
        handler: @escaping @Sendable (AVAudioSession.RouteChangeReason) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { notification in
            guard let reasonValue = notification.userInfo?[
                AVAudioSessionRouteChangeReasonKey
            ] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }
            handler(reason)
        }
    }
}
