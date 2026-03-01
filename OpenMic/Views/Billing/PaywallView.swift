import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: SubscriptionTier = .standard
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OpenMicTheme.Spacing.xl) {
                        // Header
                        VStack(spacing: OpenMicTheme.Spacing.sm) {
                            Text("Upgrade Your Voice")
                                .font(OpenMicTheme.Typography.heroTitle)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            Text("Better voice, smarter AI, more minutes")
                                .font(OpenMicTheme.Typography.body)
                                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        }
                        .padding(.top, OpenMicTheme.Spacing.xl)
                        .opacity(showContent ? 1 : 0)

                        // Tier cards
                        VStack(spacing: OpenMicTheme.Spacing.md) {
                            TierCard(
                                tier: .free,
                                isSelected: selectedTier == .free,
                                product: nil,
                                onSelect: { selectedTier = .free }
                            )

                            TierCard(
                                tier: .standard,
                                isSelected: selectedTier == .standard,
                                product: appServices.storeManager.product(for: "openmic.standard.monthly"),
                                badge: "Most Popular",
                                onSelect: { selectedTier = .standard }
                            )

                            TierCard(
                                tier: .premium,
                                isSelected: selectedTier == .premium,
                                product: appServices.storeManager.product(for: "openmic.premium.monthly"),
                                onSelect: { selectedTier = .premium }
                            )
                        }
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .opacity(showContent ? 1 : 0)

                        // Error
                        if let purchaseError {
                            Text(purchaseError)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                        }

                        // CTA
                        VStack(spacing: OpenMicTheme.Spacing.sm) {
                            if selectedTier != .free {
                                Button {
                                    Task { await purchaseSelected() }
                                } label: {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Subscribe to \(selectedTier.displayName)")
                                    }
                                }
                                .buttonStyle(.carChatPrimary)
                                .disabled(isPurchasing)
                            }

                            Button("Restore Purchases") {
                                Task { await appServices.storeManager.restorePurchases() }
                            }
                            .font(OpenMicTheme.Typography.caption)
                            .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                        .padding(.bottom, OpenMicTheme.Spacing.xxl)
                        .opacity(showContent ? 1 : 0)

                        // Credit packs
                        if !appServices.storeManager.creditProducts.isEmpty {
                            CreditPackSection(
                                products: appServices.storeManager.creditProducts,
                                onPurchase: { product in
                                    Task { await purchaseCredit(product) }
                                }
                            )
                            .padding(.horizontal, OpenMicTheme.Spacing.md)
                            .opacity(showContent ? 1 : 0)
                        }

                        // Legal
                        VStack(spacing: OpenMicTheme.Spacing.xs) {
                            Text("Subscriptions auto-renew monthly. Cancel anytime in Settings.")
                                .font(OpenMicTheme.Typography.micro)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                        .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                    }
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(OpenMicTheme.Colors.accentGradientStart)
                }
            }
        }
        .task {
            if appServices.storeManager.products.isEmpty {
                await appServices.storeManager.loadProducts()
            }
        }
        .onAppear {
            selectedTier = appServices.effectiveTier == .free ? .standard : appServices.effectiveTier
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.1)) {
                showContent = true
            }
        }
    }

    private func purchaseSelected() async {
        let productID: String
        switch selectedTier {
        case .standard: productID = "openmic.standard.monthly"
        case .premium: productID = "openmic.premium.monthly"
        default: return
        }

        guard let product = appServices.storeManager.product(for: productID) else {
            purchaseError = "Product not available"
            return
        }

        isPurchasing = true
        purchaseError = nil

        do {
            if let _ = try await appServices.storeManager.purchase(product) {
                Haptics.success()
                dismiss()
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            Haptics.error()
        }

        isPurchasing = false
    }

    private func purchaseCredit(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            if let _ = try await appServices.storeManager.purchase(product) {
                Haptics.success()
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            Haptics.error()
        }

        isPurchasing = false
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let product: Product?
    var badge: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            onSelect()
        }) {
            GlassCard(cornerRadius: OpenMicTheme.Radius.lg, padding: OpenMicTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: OpenMicTheme.Spacing.xs) {
                                Text(tier.displayName)
                                    .font(OpenMicTheme.Typography.title)
                                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                                if let badge {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(OpenMicTheme.Colors.accentGradientStart)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(tier.voiceQualityDescription)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }

                        Spacer()

                        priceLabel
                    }

                    // Features
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tier.features, id: \.self) { feature in
                            HStack(spacing: OpenMicTheme.Spacing.xs) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSelected ? OpenMicTheme.Colors.accentGradientStart : OpenMicTheme.Colors.textTertiary)

                                Text(feature)
                                    .font(OpenMicTheme.Typography.caption)
                                    .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: OpenMicTheme.Radius.lg)
                    .stroke(
                        isSelected ? OpenMicTheme.Colors.accentGradientStart : .clear,
                        lineWidth: 2
                    )
            )
        }
        .accessibilityLabel("\(tier.displayName) plan")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select")
    }

    @ViewBuilder
    private var priceLabel: some View {
        if let product {
            VStack(alignment: .trailing) {
                Text(product.displayPrice)
                    .font(OpenMicTheme.Typography.title)
                    .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                Text("/month")
                    .font(OpenMicTheme.Typography.micro)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
            }
        } else {
            Text("Free")
                .font(OpenMicTheme.Typography.title)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Credit Pack Section

private struct CreditPackSection: View {
    let products: [Product]
    let onPurchase: (Product) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OpenMicTheme.Spacing.sm) {
            Text("MINUTE PACKS")
                .font(OpenMicTheme.Typography.micro)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                .padding(.horizontal, OpenMicTheme.Spacing.xs)

            ForEach(products, id: \.id) { product in
                GlassCard(cornerRadius: OpenMicTheme.Radius.md, padding: OpenMicTheme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayName)
                                .font(OpenMicTheme.Typography.headline)
                                .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                            Text(product.description)
                                .font(OpenMicTheme.Typography.caption)
                                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                        }

                        Spacer()

                        Button(product.displayPrice) {
                            Haptics.tap()
                            onPurchase(product)
                        }
                        .font(OpenMicTheme.Typography.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, OpenMicTheme.Spacing.md)
                        .padding(.vertical, OpenMicTheme.Spacing.xs)
                        .background(OpenMicTheme.Gradients.accent)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
