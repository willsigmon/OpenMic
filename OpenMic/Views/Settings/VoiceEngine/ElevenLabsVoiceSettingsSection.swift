import SwiftUI

struct ElevenLabsVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices
    @AppStorage("elevenLabsModel") private var elevenLabsModel = ElevenLabsModel.flash.rawValue

    @State private var elevenLabsKey = ""
    @State private var hasElevenLabsKey = false
    @State private var isEditingKey = false
    @State private var voices: [ElevenLabsVoice] = []
    @State private var selectedVoiceID: String?
    @State private var isLoadingVoices = false
    @State private var voiceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            // API Key
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("ELEVENLABS SETUP")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasElevenLabsKey {
                        StatusBadge(
                            text: "Connected",
                            color: OpenMicTheme.Colors.success
                        )
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                        HStack(spacing: OpenMicTheme.Spacing.sm) {
                            LayeredFeatureIcon(
                                systemName: "key.fill",
                                color: OpenMicTheme.Colors.accentGradientStart,
                                accentShape: .none
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("API Key")
                                    .font(OpenMicTheme.Typography.headline)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                                Text(hasElevenLabsKey
                                     ? "Your key is securely stored in Keychain"
                                     : "Get one free at elevenlabs.io")
                                    .font(OpenMicTheme.Typography.caption)
                                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            }

                            Spacer()
                        }

                        if isEditingKey {
                            HStack(spacing: OpenMicTheme.Spacing.xs) {
                                HStack(spacing: OpenMicTheme.Spacing.xs) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                                    SecureField("xi-...", text: $elevenLabsKey)
                                        .font(OpenMicTheme.Typography.body)
                                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .tint(OpenMicTheme.Colors.accentGradientStart)
                                }
                                .padding(OpenMicTheme.Spacing.xs)
                                .glassBackground(cornerRadius: OpenMicTheme.Radius.sm)

                                Button("Save") {
                                    saveElevenLabsKey()
                                }
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.sm)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(Capsule().fill(OpenMicTheme.Gradients.accent))
                            }
                        } else {
                            Button(hasElevenLabsKey ? "Update Key" : "Add Key") {
                                isEditingKey = true
                            }
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }
                    }
                }
            }

            // Model picker (only when key is set)
            if hasElevenLabsKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    Text("MODEL")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)

                    ForEach(ElevenLabsModel.allCases) { model in
                        elevenLabsModelRow(model)
                    }
                }

                // Voice picker
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    VoicePickerHeader(
                        isLoading: isLoadingVoices,
                        hasVoices: !voices.isEmpty,
                        onRefresh: { Task { await fetchVoices() } }
                    )

                    if let voiceError {
                        VoiceErrorCard(error: voiceError)
                    } else if voices.isEmpty && !isLoadingVoices {
                        LoadVoicesButton { Task { await fetchVoices() } }
                    } else {
                        ForEach(voices) { voice in
                            elevenLabsVoiceRow(voice)
                        }
                    }
                }
            }
        }
        .task { await loadState() }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func elevenLabsModelRow(_ model: ElevenLabsModel) -> some View {
        let isSelected = model.rawValue == elevenLabsModel
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                elevenLabsModel = model.rawValue
            }
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: modelIcon(model),
                        color: isSelected
                            ? OpenMicTheme.Colors.accentGradientStart
                            : OpenMicTheme.Colors.textTertiary,
                        accentShape: .none
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(model.subtitle)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()

                    if isSelected {
                        StatusBadge(
                            text: "Active",
                            color: OpenMicTheme.Colors.success
                        )
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isSelected
                                ? OpenMicTheme.Colors.accentGradientStart
                                : OpenMicTheme.Colors.textTertiary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder
    private func elevenLabsVoiceRow(_ voice: ElevenLabsVoice) -> some View {
        let isSelected = voice.voiceId == selectedVoiceID
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                selectedVoiceID = voice.voiceId
                saveSelectedVoice(voice.voiceId)
            }
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(OpenMicTheme.Colors.speaking.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(voice.name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(OpenMicTheme.Colors.speaking)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.name)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if !voice.subtitle.isEmpty {
                            Text(voice.subtitle)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(voice.categoryLabel)
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .glassBackground(cornerRadius: OpenMicTheme.Radius.pill)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isSelected
                                ? OpenMicTheme.Colors.accentGradientStart
                                : OpenMicTheme.Colors.textTertiary
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Helpers

    private func modelIcon(_ model: ElevenLabsModel) -> String {
        switch model {
        case .flash: "bolt.fill"
        case .turbo: "gauge.with.dots.needle.67percent"
        case .multilingualV2: "globe"
        case .englishV1: "textformat"
        }
    }

    // MARK: - Actions

    private func loadState() async {
        do {
            let key = try await appServices.keychainManager.getElevenLabsKey()
            hasElevenLabsKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasElevenLabsKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedVoiceID = persona.elevenLabsVoiceID
        }
    }

    private func saveElevenLabsKey() {
        Task {
            do {
                if elevenLabsKey.isEmpty {
                    try await appServices.keychainManager.deleteElevenLabsKey()
                    hasElevenLabsKey = false
                } else {
                    try await appServices.keychainManager.saveElevenLabsKey(elevenLabsKey)
                    hasElevenLabsKey = true
                }
                isEditingKey = false
                elevenLabsKey = ""
                voices = []
            } catch {
                voiceError = error.localizedDescription
            }
        }
    }

    private func fetchVoices() async {
        isLoadingVoices = true
        voiceError = nil

        do {
            guard let key = try await appServices.keychainManager.getElevenLabsKey(),
                  !key.isEmpty else {
                voiceError = "API key not configured"
                isLoadingVoices = false
                return
            }

            let manager = ElevenLabsVoiceManager()
            voices = try await manager.voices(apiKey: key)
        } catch let error as ElevenLabsError {
            voiceError = error.errorDescription
        } catch {
            voiceError = error.localizedDescription
        }

        isLoadingVoices = false
    }

    private func saveSelectedVoice(_ voiceID: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.elevenLabsVoiceID = voiceID
        try? appServices.modelContainer.mainContext.save()
    }
}
