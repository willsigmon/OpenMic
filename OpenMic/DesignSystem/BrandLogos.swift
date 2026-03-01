import SwiftUI

// MARK: - Brand Logo View

/// Renders the official brand logo for each AI provider from bundled PNG assets.
/// Apple uses the SF Symbol `apple.logo` since it's Apple's own platform.
/// Pass a `tint` color to force monochrome rendering.
/// Without tint, providers render in their official full-color branding.
struct BrandLogo: View {
    let provider: AIProviderType
    let size: CGFloat
    let tint: Color?

    init(_ provider: AIProviderType, size: CGFloat = 32, tint: Color? = nil) {
        self.provider = provider
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Group {
            switch provider {
            case .openclaw:
                // OpenClaw uses SF Symbol — self-hosted agent
                if let tint {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: size, height: size)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0x6C5CE7), Color(hex: 0xA29BFE)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: size)
                }
            case .apple:
                // Apple's own SF Symbol — no need for a bundled asset
                if let tint {
                    Image(systemName: "apple.logo")
                        .font(.system(size: size * 0.55, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: size, height: size)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: size * 0.55, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xA8A8A8), Color(hex: 0xE0E0E0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: size)
                }
            case .gemini:
                // Gemini has its own multicolor logo — always render original
                Image("ProviderLogos/gemini-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.75, height: size * 0.75)
                    .frame(width: size, height: size)
            default:
                if let tint {
                    // Monochrome variant for constrained UI contexts.
                    Image("ProviderLogos/\(assetName)-logo")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(tint)
                        .frame(width: size * 0.75, height: size * 0.75)
                        .frame(width: size, height: size)
                } else {
                    // Preferred: official full-color branding.
                    Image("ProviderLogos/\(assetName)-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.75, height: size * 0.75)
                        .frame(width: size, height: size)
                }
            }
        }
    }

    private var assetName: String {
        switch provider {
        case .openAI: "openai"
        case .anthropic: "claude"
        case .gemini: "gemini"
        case .grok: "xai"
        case .ollama: "ollama"
        case .apple: "apple" // unused — handled by SF Symbol above
        case .openclaw: "openclaw" // unused — handled by SF Symbol above
        }
    }
}

// MARK: - Brand Logo Card (Logo with branded background)

/// A card-style logo container with brand-colored gradient background
struct BrandLogoCard: View {
    let provider: AIProviderType
    let size: CGFloat

    init(_ provider: AIProviderType, size: CGFloat = 48) {
        self.provider = provider
        self.size = size
    }

    var body: some View {
        ZStack {
            // Branded gradient background
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(
                    LinearGradient(
                        colors: brandGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Logo mark
            BrandLogo(provider, size: size * 0.65)
        }
        .shadow(color: brandGlowColor.opacity(0.3), radius: 8, y: 2)
    }

    private var brandGradientColors: [Color] {
        switch provider {
        case .openAI:
            [Color(hex: 0x0D8C6D), Color(hex: 0x10A37F)]
        case .anthropic:
            [Color(hex: 0x2A1F14), Color(hex: 0x3D2B1A)]
        case .gemini:
            [Color(hex: 0x1A237E), Color(hex: 0x283593)]
        case .grok:
            [Color(hex: 0x1A1A1A), Color(hex: 0x2A2A2A)]
        case .ollama:
            [Color(hex: 0x2A2A2A), Color(hex: 0x3A3A3A)]
        case .apple:
            [Color(hex: 0x1C1C1E), Color(hex: 0x2C2C2E)]
        case .openclaw:
            [Color(hex: 0x3D2B7A), Color(hex: 0x6C5CE7)]
        }
    }

    private var brandGlowColor: Color {
        OpenMicTheme.Colors.providerColor(provider)
    }
}
