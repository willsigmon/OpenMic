import SwiftUI

struct CartesiaVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices

    @State private var cartesiaKey = ""
    @State private var hasCartesiaKey = false
    @State private var isEditingCartesiaKey = false
    @State private var cartesiaVoices: [CartesiaVoice] = []
    @State private var selectedCartesiaVoiceID: String?
    @State private var isLoadingCartesiaVoices = false
    @State private var cartesiaVoiceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("CARTESIA SETUP")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasCartesiaKey {
                        StatusBadge(text: "Connected", color: OpenMicTheme.Colors.success)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

                BYOKKeyCard(
                    hasKey: hasCartesiaKey,
                    isEditing: $isEditingCartesiaKey,
                    keyText: $cartesiaKey,
                    placeholder: "sk-...",
                    providerURL: "play.cartesia.ai",
                    onSave: saveCartesiaKey
                )
            }

            if hasCartesiaKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    VoicePickerHeader(
                        isLoading: isLoadingCartesiaVoices,
                        hasVoices: !cartesiaVoices.isEmpty,
                        onRefresh: { Task { await fetchCartesiaVoices() } }
                    )

                    if let cartesiaVoiceError {
                        VoiceErrorCard(error: cartesiaVoiceError)
                    } else if cartesiaVoices.isEmpty && !isLoadingCartesiaVoices {
                        LoadVoicesButton { Task { await fetchCartesiaVoices() } }
                    } else {
                        ForEach(cartesiaVoices) { voice in
                            SimpleVoiceRow(
                                name: voice.name,
                                detail: voice.description,
                                isSelected: voice.id == selectedCartesiaVoiceID
                            ) {
                                selectedCartesiaVoiceID = voice.id
                                saveCartesiaVoice(voice.id)
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
            let key = try await appServices.keychainManager.getCartesiaKey()
            hasCartesiaKey = key != nil && !(key?.isEmpty ?? true)
        } catch {
            hasCartesiaKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedCartesiaVoiceID = persona.cartesiaVoiceID
        }
    }

    private func saveCartesiaKey() {
        Task {
            do {
                if cartesiaKey.isEmpty {
                    try await appServices.keychainManager.deleteCartesiaKey()
                    hasCartesiaKey = false
                } else {
                    try await appServices.keychainManager.saveCartesiaKey(cartesiaKey)
                    hasCartesiaKey = true
                }
                isEditingCartesiaKey = false
                cartesiaKey = ""
                cartesiaVoices = []
            } catch {
                cartesiaVoiceError = error.localizedDescription
            }
        }
    }

    private func fetchCartesiaVoices() async {
        isLoadingCartesiaVoices = true
        cartesiaVoiceError = nil

        do {
            guard let key = try await appServices.keychainManager.getCartesiaKey(),
                  !key.isEmpty else {
                cartesiaVoiceError = "API key not configured"
                isLoadingCartesiaVoices = false
                return
            }

            let manager = CartesiaVoiceManager()
            cartesiaVoices = try await manager.voices(apiKey: key)
        } catch let error as CartesiaTTSError {
            cartesiaVoiceError = error.errorDescription
        } catch {
            cartesiaVoiceError = error.localizedDescription
        }

        isLoadingCartesiaVoices = false
    }

    private func saveCartesiaVoice(_ voiceID: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.cartesiaVoiceID = voiceID
        try? appServices.modelContainer.mainContext.save()
    }
}
