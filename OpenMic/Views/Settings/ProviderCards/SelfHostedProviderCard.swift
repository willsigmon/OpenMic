import SwiftUI

struct SelfHostedProviderCard: View {
    let provider: AIProviderType
    let isActive: Bool
    @State private var baseURL: String = ""
    @State private var isEditing = false
    @State private var isTesting = false
    @State private var testResult: Bool?

    private var brandColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }

    private var baseURLKey: String {
        switch provider {
        case .openclaw:
            return "openclawBaseURL"
        case .ollama:
            return "ollamaBaseURL"
        default:
            return "\(provider.rawValue)BaseURL"
        }
    }

    private var baseURLPlaceholder: String {
        switch provider {
        case .openclaw:
            return "http://your-server:8101"
        case .ollama:
            return "http://192.168.1.10:11434"
        default:
            return "http://your-server"
        }
    }

    private var endpointTitle: String {
        switch provider {
        case .ollama:
            return "Ollama Endpoint"
        default:
            return "Base URL"
        }
    }

    private var guidanceText: String? {
        switch provider {
        case .ollama:
            return "Use http:// with your computer's LAN IP (not localhost). If needed, run Ollama with OLLAMA_HOST=0.0.0.0:11434."
        case .openclaw:
            return nil
        default:
            return nil
        }
    }

    private var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let withScheme: String
        if trimmed.contains("://") {
            withScheme = trimmed
        } else {
            withScheme = "http://\(trimmed)"
        }

        return withScheme.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: OpenMicTheme.Spacing.md) {
                BrandLogoCard(provider, size: 52)

                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xxxs) {
                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Text(provider.displayName)
                            .font(OpenMicTheme.Typography.headline)
                            .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                        if isActive {
                            Text("Active")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(OpenMicTheme.Colors.success.opacity(0.12))
                                )
                                .overlay(
                                    Capsule().strokeBorder(OpenMicTheme.Colors.success.opacity(0.25), lineWidth: 0.5)
                                )
                        }

                        Text("Self-Hosted")
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(brandColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(brandColor.opacity(0.12))
                            )
                    }

                    Text(provider.tagline)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }

                Spacer()

                if !isEditing {
                    Button {
                        baseURL = UserDefaults.standard.string(forKey: baseURLKey) ?? ""
                        withAnimation(OpenMicTheme.Animation.fast) {
                            isEditing = true
                        }
                    } label: {
                        Text("Configure")
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(brandColor)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xxs)
                            .background(
                                Capsule().fill(brandColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule().strokeBorder(brandColor.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(OpenMicTheme.Spacing.md)

            if isEditing {
                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Divider()
                        .background(brandColor.opacity(0.2))

                    VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.xs) {
                        Text(endpointTitle)
                            .font(OpenMicTheme.Typography.micro)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)

                        HStack(spacing: OpenMicTheme.Spacing.xs) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(brandColor.opacity(0.6))

                            TextField(baseURLPlaceholder, text: $baseURL)
                                .font(OpenMicTheme.Typography.body)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .tint(brandColor)
                        }
                        .padding(OpenMicTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                                .fill(OpenMicTheme.Colors.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.sm)
                                .strokeBorder(brandColor.opacity(0.15), lineWidth: 0.5)
                        )

                        if let guidanceText {
                            Text(guidanceText)
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }
                    }

                    HStack(spacing: OpenMicTheme.Spacing.xs) {
                        Button("Cancel") {
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                                testResult = nil
                            }
                        }
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .padding(.vertical, OpenMicTheme.Spacing.xs)

                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 4) {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .tint(.white)
                                } else {
                                    Image(systemName: testResult == true ? "checkmark" : "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(testResult == true ? "Connected" : "Test")
                                    .font(OpenMicTheme.Typography.caption)
                            }
                            .foregroundStyle(testResult == true ? OpenMicTheme.Colors.success : OpenMicTheme.Colors.textSecondary)
                            .padding(.horizontal, OpenMicTheme.Spacing.sm)
                            .padding(.vertical, OpenMicTheme.Spacing.xs)
                            .background(
                                Capsule().fill(OpenMicTheme.Colors.surfaceGlass)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isTesting)

                        Spacer()

                        Button {
                            UserDefaults.standard.set(normalizedBaseURL, forKey: baseURLKey)
                            UserDefaults.standard.set(provider.rawValue, forKey: "selectedProvider")
                            Haptics.tap()
                            withAnimation(OpenMicTheme.Animation.fast) {
                                isEditing = false
                            }
                        } label: {
                            Text("Save")
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, OpenMicTheme.Spacing.lg)
                                .padding(.vertical, OpenMicTheme.Spacing.xs)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [brandColor, brandColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(normalizedBaseURL.isEmpty)
                        .opacity(normalizedBaseURL.isEmpty ? 0.5 : 1)
                    }
                }
                .padding(.horizontal, OpenMicTheme.Spacing.md)
                .padding(.bottom, OpenMicTheme.Spacing.md)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .fill(.ultraThinMaterial.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isActive ? OpenMicTheme.Colors.success.opacity(0.35) : brandColor.opacity(0.25),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(provider.displayName), \(isActive ? "active, " : "")self-hosted")
    }

    private func testConnection() {
        let baseURLToTest = normalizedBaseURL
        guard !baseURLToTest.isEmpty else {
            testResult = false
            return
        }

        isTesting = true
        testResult = nil
        Task {
            do {
                let providerToTest: any AIProvider
                switch provider {
                case .openclaw:
                    providerToTest = OpenClawProvider(
                        apiKey: "",
                        baseURL: baseURLToTest,
                        model: provider.defaultModel
                    )
                case .ollama:
                    providerToTest = OllamaProvider(
                        baseURL: baseURLToTest,
                        model: provider.defaultModel
                    )
                default:
                    throw AIProviderError.configurationMissing("Unsupported self-hosted provider")
                }

                let result = try await providerToTest.validateKey()
                testResult = result
            } catch {
                testResult = false
            }
            isTesting = false
        }
    }
}
