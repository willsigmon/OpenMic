import SwiftUI

struct GoogleCloudVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices

    @State private var googleCloudKey = ""
    @State private var hasGoogleCloudKey = false
    @State private var isEditingGoogleCloudKey = false
    @State private var googleCloudVoices: [GoogleCloudVoice] = []
    @State private var selectedGoogleCloudVoiceID: String?
    @State private var isLoadingGoogleCloudVoices = false
    @State private var googleCloudVoiceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("GOOGLE CLOUD TTS")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasGoogleCloudKey {
                        StatusBadge(text: "Connected", color: OpenMicTheme.Colors.success)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

                BYOKKeyCard(
                    hasKey: hasGoogleCloudKey,
                    isEditing: $isEditingGoogleCloudKey,
                    keyText: $googleCloudKey,
                    placeholder: "AIza...",
                    providerURL: "console.cloud.google.com",
                    onSave: saveGoogleCloudKey
                )
            }

            if hasGoogleCloudKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    VoicePickerHeader(
                        isLoading: isLoadingGoogleCloudVoices,
                        hasVoices: !googleCloudVoices.isEmpty,
                        onRefresh: { Task { await fetchGoogleCloudVoices() } }
                    )

                    if let googleCloudVoiceError {
                        VoiceErrorCard(error: googleCloudVoiceError)
                    } else if googleCloudVoices.isEmpty && !isLoadingGoogleCloudVoices {
                        LoadVoicesButton { Task { await fetchGoogleCloudVoices() } }
                    } else {
                        ForEach(googleCloudVoices) { voice in
                            SimpleVoiceRow(
                                name: voice.name,
                                detail: voice.languageCodes.first ?? "",
                                isSelected: voice.name == selectedGoogleCloudVoiceID
                            ) {
                                selectedGoogleCloudVoiceID = voice.name
                                saveGoogleCloudVoice(voice.name)
                            }
                        }
                    }
                }
            }
        }
        .task { await loadState() }
    }

    // MARK: - Actions

    private func loadState() async {
        do {
            let key = try await appServices.keychainManager.getGoogleCloudKey()
            hasGoogleCloudKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasGoogleCloudKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedGoogleCloudVoiceID = persona.googleCloudVoiceID
        }
    }

    private func saveGoogleCloudKey() {
        Task {
            do {
                if googleCloudKey.isEmpty {
                    try await appServices.keychainManager.deleteGoogleCloudKey()
                    hasGoogleCloudKey = false
                } else {
                    try await appServices.keychainManager.saveGoogleCloudKey(googleCloudKey)
                    hasGoogleCloudKey = true
                }
                isEditingGoogleCloudKey = false
                googleCloudKey = ""
                googleCloudVoices = []
            } catch {
                googleCloudVoiceError = error.localizedDescription
            }
        }
    }

    private func fetchGoogleCloudVoices() async {
        isLoadingGoogleCloudVoices = true
        googleCloudVoiceError = nil

        do {
            guard let key = try await appServices.keychainManager.getGoogleCloudKey(),
                  !key.isEmpty else {
                googleCloudVoiceError = "API key not configured"
                isLoadingGoogleCloudVoices = false
                return
            }

            let manager = GoogleCloudVoiceManager()
            googleCloudVoices = try await manager.voices(apiKey: key)
        } catch let error as GoogleCloudTTSError {
            googleCloudVoiceError = error.errorDescription
        } catch {
            googleCloudVoiceError = error.localizedDescription
        }

        isLoadingGoogleCloudVoices = false
    }

    private func saveGoogleCloudVoice(_ voiceID: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.googleCloudVoiceID = voiceID
        try? appServices.modelContainer.mainContext.save()
    }
}
