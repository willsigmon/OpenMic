import SwiftUI

struct OpenAIVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices
    @AppStorage("openAITTSModel") private var openAITTSModel = OpenAITTSModel.tts1.rawValue

    @State private var hasOpenAIKey = false
    @State private var selectedOpenAIVoice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            // Connection status
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("OPENAI TTS")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasOpenAIKey {
                        StatusBadge(
                            text: "Connected",
                            color: OpenMicTheme.Colors.success
                        )
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.md) {
                    HStack(spacing: OpenMicTheme.Spacing.sm) {
                        LayeredFeatureIcon(
                            systemName: "brain.head.profile.fill",
                            color: OpenMicTheme.Colors.accentGradientStart,
                            accentShape: .none
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("API Key")
                                .font(OpenMicTheme.Typography.headline)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            Text(hasOpenAIKey
                                 ? "Uses your existing OpenAI key from AI provider setup"
                                 : "Add an OpenAI key in AI Provider settings first")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }

                        Spacer()
                    }
                }
            }

            if hasOpenAIKey {
                // Model picker
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    Text("MODEL")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)

                    ForEach(OpenAITTSModel.allCases) { model in
                        openAIModelRow(model)
                    }
                }

                // Voice picker
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    Text("VOICE")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)

                    ForEach(OpenAITTSVoice.allCases) { voice in
                        openAIVoiceRow(voice)
                    }
                }
            }
        }
        .task { await loadState() }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func openAIModelRow(_ model: OpenAITTSModel) -> some View {
        let isSelected = model.rawValue == openAITTSModel
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                openAITTSModel = model.rawValue
            }
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    LayeredFeatureIcon(
                        systemName: model == .tts1 ? "bolt.fill" : "sparkles",
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
    private func openAIVoiceRow(_ voice: OpenAITTSVoice) -> some View {
        let isSelected = voice.rawValue == selectedOpenAIVoice
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                selectedOpenAIVoice = voice.rawValue
                saveOpenAIVoice(voice.rawValue)
            }
        } label: {
            GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                HStack(spacing: OpenMicTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(OpenMicTheme.Colors.speaking.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(voice.displayName.prefix(1)))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(OpenMicTheme.Colors.speaking)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        Text(voice.description)
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                    }

                    Spacer()

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

    // MARK: - Actions

    private func loadState() async {
        do {
            let key = try await appServices.keychainManager.getAPIKey(for: .openAI)
            hasOpenAIKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasOpenAIKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedOpenAIVoice = persona.openAITTSVoice ?? OpenAITTSVoice.nova.rawValue
        }
    }

    private func saveOpenAIVoice(_ voiceName: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.openAITTSVoice = voiceName
        try? appServices.modelContainer.mainContext.save()
    }
}
