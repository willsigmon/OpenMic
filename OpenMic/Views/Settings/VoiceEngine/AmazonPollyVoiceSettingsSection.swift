import SwiftUI

struct AmazonPollyVoiceSettingsSection: View {
    @Environment(AppServices.self) private var appServices

    @State private var amazonPollyAccessKey = ""
    @State private var amazonPollySecretKey = ""
    @State private var hasAmazonPollyKey = false
    @State private var isEditingAmazonPollyKey = false
    @State private var selectedAmazonPollyVoiceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                HStack(spacing: OpenMicTheme.Spacing.xs) {
                    Text("AMAZON POLLY SETUP")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                    if hasAmazonPollyKey {
                        StatusBadge(text: "Connected", color: OpenMicTheme.Colors.success)
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
                                Text("AWS Credentials")
                                    .font(OpenMicTheme.Typography.headline)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                                Text(hasAmazonPollyKey
                                     ? "Your keys are securely stored in Keychain"
                                     : "Requires AWS access key + secret key")
                                    .font(OpenMicTheme.Typography.caption)
                                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                            }

                            Spacer()
                        }

                        if isEditingAmazonPollyKey {
                            VStack(spacing: OpenMicTheme.Spacing.xs) {
                                HStack(spacing: OpenMicTheme.Spacing.xs) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                                    SecureField("Access Key ID", text: $amazonPollyAccessKey)
                                        .font(OpenMicTheme.Typography.body)
                                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .tint(OpenMicTheme.Colors.accentGradientStart)
                                }
                                .padding(OpenMicTheme.Spacing.xs)
                                .glassBackground(cornerRadius: OpenMicTheme.Radius.sm)

                                HStack(spacing: OpenMicTheme.Spacing.xs) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                                    SecureField("Secret Access Key", text: $amazonPollySecretKey)
                                        .font(OpenMicTheme.Typography.body)
                                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .tint(OpenMicTheme.Colors.accentGradientStart)
                                }
                                .padding(OpenMicTheme.Spacing.xs)
                                .glassBackground(cornerRadius: OpenMicTheme.Radius.sm)

                                Button("Save") {
                                    saveAmazonPollyKeys()
                                }
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.sm)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(Capsule().fill(OpenMicTheme.Gradients.accent))
                            }
                        } else {
                            Button(hasAmazonPollyKey ? "Update Keys" : "Add Keys") {
                                isEditingAmazonPollyKey = true
                            }
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                        }
                    }
                }
            }

            if hasAmazonPollyKey {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                    Text("VOICE")
                        .font(OpenMicTheme.Typography.micro)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.xs)

                    ForEach(AmazonPollyVoiceCatalog.englishVoices) { voice in
                        SimpleVoiceRow(
                            name: voice.name,
                            detail: "\(voice.gender) \u{2022} \(voice.engine)",
                            isSelected: voice.id == selectedAmazonPollyVoiceID
                        ) {
                            selectedAmazonPollyVoiceID = voice.id
                            saveAmazonPollyVoice(voice.id)
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
            let accessKey = try await appServices.keychainManager.getAmazonPollyAccessKey()
            hasAmazonPollyKey = accessKey != nil && !(accessKey?.isEmpty ?? true)
        } catch {
            hasAmazonPollyKey = false
        }

        if let persona = fetchActivePersona(from: appServices) {
            selectedAmazonPollyVoiceID = persona.amazonPollyVoiceID
        }
    }

    private func saveAmazonPollyKeys() {
        Task {
            do {
                if amazonPollyAccessKey.isEmpty || amazonPollySecretKey.isEmpty {
                    try await appServices.keychainManager.deleteAmazonPollyKeys()
                    hasAmazonPollyKey = false
                } else {
                    try await appServices.keychainManager.saveAmazonPollyKeys(
                        accessKey: amazonPollyAccessKey,
                        secretKey: amazonPollySecretKey
                    )
                    hasAmazonPollyKey = true
                }
                isEditingAmazonPollyKey = false
                amazonPollyAccessKey = ""
                amazonPollySecretKey = ""
            } catch {
                // silently fail
            }
        }
    }

    private func saveAmazonPollyVoice(_ voiceID: String) {
        guard let persona = fetchActivePersona(from: appServices) else { return }
        persona.amazonPollyVoiceID = voiceID
        try? appServices.modelContainer.mainContext.save()
    }
}
