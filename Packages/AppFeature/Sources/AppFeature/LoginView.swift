#if os(iOS)
import Auth
import CoderAPI
import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct LoginView: View {
    @Bindable var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WTColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: WTSpace.xxl) {
                    HeroHeader()

                    Group {
                        switch store.phase {
                        case .enteringURL:
                            URLEntryStep(store: store)
                        case .probingMethods:
                            ProgressStep(label: "Probing deployment…")
                        case .choosingMethod:
                            MethodPickerStep(store: store)
                        case .enteringPassword:
                            PasswordEntryStep(store: store)
                        case .openingOIDC:
                            ProgressStep(label: "Opening sign-in…")
                        case .finalizing:
                            ProgressStep(label: "Signing in…")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Spacer(minLength: WTSpace.xxxl)
                }
                .padding(.horizontal, WTSpace.xl)
                .padding(.top, WTSpace.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .animation(WTMotion.smooth, value: store.phase)
        .alert("Sign-in error",
               isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.send(.dismissError) } })) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.error ?? "")
        }
    }
}

// MARK: - Hero

private struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WTSpace.md) {
            HStack(alignment: .firstTextBaseline, spacing: WTSpace.sm) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WTColor.accent)
                Text("Workspace Terminal")
                    .font(WTFont.captionEmphasized)
                    .foregroundStyle(WTColor.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.5)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: WTSpace.xs) {
                Text("Sign in")
                    .font(WTFont.display)
                    .foregroundStyle(WTColor.textPrimary)
                WTAnimatedCursor(height: 36)
                    .padding(.bottom, 4)
                Spacer()
            }

            Text("Connect to your Coder deployment to access workspaces and terminals.")
                .font(WTFont.body)
                .foregroundStyle(WTColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Steps

private struct URLEntryStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: WTSpace.lg) {
            WTInputField(
                label: "Coder deployment",
                placeholder: "https://coder.example.com",
                icon: "globe",
                text: $store.urlInput.sending(\.urlInputChanged)
            )

            WTPrimaryButton("Continue", icon: "arrow.right", action: { store.send(.continueWithURLTapped) })
                .opacity(store.urlInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .disabled(store.urlInput.trimmingCharacters(in: .whitespaces).isEmpty)

            Text("Self-hosted deployments are supported. Your URL never leaves your device.")
                .font(WTFont.subheadline)
                .foregroundStyle(WTColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, WTSpace.sm)
                .padding(.horizontal, WTSpace.lg)
        }
    }
}

private struct MethodPickerStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: WTSpace.md) {
            HStack {
                Text("How would you like to sign in?")
                    .font(WTFont.headline)
                    .foregroundStyle(WTColor.textPrimary)
                Spacer()
            }
            ForEach(Array(store.availableMethods.enumerated()), id: \.offset) { _, method in
                WTOAuthButton(variant: variant(for: method)) {
                    store.send(.methodTapped(method))
                }
            }
        }
    }

    private func variant(for method: AuthMethod) -> WTOAuthButton.Variant {
        switch method {
        case .password:                  return .password
        case .github:                    return .github
        case let .oidc(text, iconURL):   return .oidc(displayText: text, iconURL: iconURL)
        }
    }
}

private struct PasswordEntryStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: WTSpace.lg) {
            WTInputField(
                label: "Email",
                placeholder: "you@example.com",
                icon: "envelope",
                text: $store.emailInput.sending(\.emailInputChanged)
            )
            WTInputField(
                label: "Password",
                placeholder: "••••••••",
                icon: "lock",
                isSecure: true,
                text: $store.passwordInput.sending(\.passwordInputChanged)
            )
            WTPrimaryButton("Sign in", icon: "arrow.right", action: { store.send(.submitPasswordTapped) })
                .opacity(canSubmit ? 1 : 0.4)
                .disabled(!canSubmit)
        }
    }

    private var canSubmit: Bool {
        !store.emailInput.isEmpty && !store.passwordInput.isEmpty
    }
}

private struct ProgressStep: View {
    let label: String
    var body: some View {
        VStack(spacing: WTSpace.md) {
            WTCinematicLoader(label: label)
                .frame(height: 220)
        }
    }
}
#endif
