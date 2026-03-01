import SwiftUI
import AuthenticationServices

struct SignInStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AppServices.self) private var appServices
    @State private var showContent = false
    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        ZStack {
            OpenMicTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: OpenMicTheme.Spacing.xxl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(OpenMicTheme.Colors.glowCyan)
                        .frame(width: 100, height: 100)
                        .blur(radius: 25)
                        .opacity(0.4)

                    GradientIcon(
                        systemName: "person.crop.circle.badge.checkmark",
                        gradient: OpenMicTheme.Gradients.accent,
                        size: 80,
                        iconSize: 36,
                        glowColor: OpenMicTheme.Colors.glowCyan,
                        isAnimated: false
                    )
                }
                .opacity(showContent ? 1 : 0)

                VStack(spacing: OpenMicTheme.Spacing.sm) {
                    Text("Save Your Conversations")
                        .font(OpenMicTheme.Typography.heroTitle)
                        .foregroundStyle(OpenMicTheme.Colors.textPrimary)

                    Text("Sign in to sync across devices and unlock your full history")
                        .font(OpenMicTheme.Typography.body)
                        .foregroundStyle(OpenMicTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OpenMicTheme.Spacing.xxl)
                }
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Error message
                if let signInError {
                    Text(signInError)
                        .font(OpenMicTheme.Typography.caption)
                        .foregroundStyle(OpenMicTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OpenMicTheme.Spacing.xl)
                }

                // Sign in with Apple
                VStack(spacing: OpenMicTheme.Spacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: OpenMicTheme.Radius.md))
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.6 : 1.0)

                    Button("Skip for Now") {
                        Haptics.tap()
                        viewModel.advance()
                    }
                    .font(OpenMicTheme.Typography.headline)
                    .foregroundStyle(OpenMicTheme.Colors.textTertiary)
                }
                .padding(.horizontal, OpenMicTheme.Spacing.xl)
                .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(OpenMicTheme.Animation.smooth.delay(0.2)) {
                showContent = true
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8)
            else {
                signInError = "Failed to get Apple ID credentials"
                return
            }

            isSigningIn = true
            signInError = nil

            Task {
                do {
                    // Generate nonce for Supabase auth
                    try await appServices.authManager.signInWithApple(
                        idToken: tokenString,
                        nonce: "" // Supabase handles nonce internally
                    )
                    Haptics.success()
                    viewModel.advance()
                } catch {
                    signInError = "Sign in failed: \(error.localizedDescription)"
                    Haptics.error()
                }
                isSigningIn = false
            }

        case .failure(let error):
            // User cancelled or other error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                signInError = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }
}
