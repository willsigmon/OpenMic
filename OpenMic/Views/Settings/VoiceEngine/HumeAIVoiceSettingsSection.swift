import SwiftUI

struct HumeAIVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices

    @State private var humeAIKey = ""
    @State private var hasHumeAIKey = false
    @State private var isEditingHumeKey = false
    @State private var humeVoices: [HumeAIVoice] = []
    @State private var selectedHumeVoiceID: String?
    @State private var isLoadingHumeVoices = false
    @State private var humeVoiceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            // API Key
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("HUME AI SETUP")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasHumeAIKey {
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

                                Text(hasHumeAIKey
                                     ? "Your key is securely stored in Keychain"
                                     : "Get one at platform.hume.ai")
                                    .font(OpenMicTheme.Typography.caption)
                                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            }

                            Spacer()
                        }

                        if isEditingHumeKey {
                            HStack(spacing: OpenMicTheme.Spacing.xs) {
                                HStack(spacing: OpenMicTheme.Spacing.xs) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                                    SecureField("hume-...", text: $humeAIKey)
                                        .font(OpenMicTheme.Typography.body)
                                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .tint(OpenMicTheme.Colors.accentGradientStart)
                                }
                                .padding(OpenMicTheme.Spacing.xs)
                                .glassBackground(cornerRadius: OpenMicTheme.Radius.sm)

                                Button("Save") {
                                    saveHumeAIKey()
                                }
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.sm)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(Capsule().fill(OpenMicTheme.Gradients.accent))
                            }
                        } else {
                            Button(hasHumeAIKey ? "Update Key" : "Add Key") {
                                isEditingHumeKey = true
                            }
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }
                    }
                }
            }

            // Voice picker (only when key is set)
            if hasHumeAIKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    VoicePickerHeader(
                        isLoading: isLoadingHumeVoices,
                        hasVoices: !humeVoices.isEmpty,
                        onRefresh: { Task { await fetchHumeVoices() } }
                    )

                    if let humeVoiceError {
                        VoiceErrorCard(error: humeVoiceError)
                    } else if humeVoices.isEmpty && !isLoadingHumeVoices {
                        LoadVoicesButton { Task { await fetchHumeVoices() } }
                    } else {
                        ForEach(humeVoices) { voice in
                            humeVoiceRow(voice)
                        }
                    }
                }
            }
        }
        .task { await loadState() }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func humeVoiceRow(_ voice: HumeAIVoice) -> some View {
        let isSelected = voice.name == selectedHumeVoiceID
        Button {
            withAnimation(OpenMicTheme.Animation.fast) {
                selectedHumeVoiceID = voice.name
                saveHumeVoice(voice.name)
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

                        if !voice.description.isEmpty {
                            Text(voice.description)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                                .lineLimit(1)
                        }
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
            let key = try await appServices.keychainManager.getHumeAIKey()
            hasHumeAIKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasHumeAIKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedHumeVoiceID = persona.humeAIVoiceID
        }
    }

    private func saveHumeAIKey() {
        Task {
            do {
                if humeAIKey.isEmpty {
                    try await appServices.keychainManager.deleteHumeAIKey()
                    hasHumeAIKey = false
                } else {
                    try await appServices.keychainManager.saveHumeAIKey(humeAIKey)
                    hasHumeAIKey = true
                }
                isEditingHumeKey = false
                humeAIKey = ""
                humeVoices = []
            } catch {
                humeVoiceError = error.localizedDescription
            }
        }
    }

    private func fetchHumeVoices() async {
        isLoadingHumeVoices = true
        humeVoiceError = nil

        do {
            guard let key = try await appServices.keychainManager.getHumeAIKey(),
                  !key.isEmpty else {
                humeVoiceError = "API key not configured"
                isLoadingHumeVoices = false
                return
            }

            let manager = HumeAIVoiceManager()
            humeVoices = try await manager.voices(apiKey: key)
        } catch let error as HumeAIError {
            humeVoiceError = error.errorDescription
        } catch {
            humeVoiceError = error.localizedDescription
        }

        isLoadingHumeVoices = false
    }

    private func saveHumeVoice(_ voiceName: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.humeAIVoiceID = voiceName
        try? appServices.modelContainer.mainContext.save()
    }
}
