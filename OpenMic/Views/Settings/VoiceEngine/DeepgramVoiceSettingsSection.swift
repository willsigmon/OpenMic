import SwiftUI

struct DeepgramVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices

    @State private var deepgramKey = ""
    @State private var hasDeepgramKey = false
    @State private var isEditingDeepgramKey = false
    @State private var selectedDeepgramVoiceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("DEEPGRAM SETUP")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasDeepgramKey {
                        StatusBadge(text: "Connected", color: OpenMicTheme.Colors.success)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

                BYOKKeyCard(
                    hasKey: hasDeepgramKey,
                    isEditing: $isEditingDeepgramKey,
                    keyText: $deepgramKey,
                    placeholder: "dg-...",
                    providerURL: "console.deepgram.com",
                    onSave: saveDeepgramKey
                )
            }

            if hasDeepgramKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    Text("VOICE")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)

                    ForEach(DeepgramVoiceCatalog.aura2Voices) { voice in
                        SimpleVoiceRow(
                            name: voice.name,
                            detail: voice.description,
                            isSelected: voice.id == selectedDeepgramVoiceID
                        ) {
                            selectedDeepgramVoiceID = voice.id
                            saveDeepgramVoice(voice.id)
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
            let key = try await appServices.keychainManager.getDeepgramKey()
            hasDeepgramKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasDeepgramKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedDeepgramVoiceID = persona.deepgramVoiceID
        }
    }

    private func saveDeepgramKey() {
        Task {
            do {
                if deepgramKey.isEmpty {
                    try await appServices.keychainManager.deleteDeepgramKey()
                    hasDeepgramKey = false
                } else {
                    try await appServices.keychainManager.saveDeepgramKey(deepgramKey)
                    hasDeepgramKey = true
                }
                isEditingDeepgramKey = false
                deepgramKey = ""
            } catch {
                // silently fail
            }
        }
    }

    private func saveDeepgramVoice(_ voiceID: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.deepgramVoiceID = voiceID
        try? appServices.modelContainer.mainContext.save()
    }
}
