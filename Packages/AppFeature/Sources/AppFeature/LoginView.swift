#if os(iOS)
import Auth
import CoderAPI
import ComposableArchitecture
import SwiftUI

public struct LoginView: View {
    @Bindable var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            switch store.phase {
            case .enteringURL:
                URLEntryStep(store: store)
            case .probingMethods:
                ProgressStep(label: "Connecting…")
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
        .navigationTitle("Sign in to Coder")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign-in error",
               isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.send(.dismissError) } })) {
            Button("OK", role: .cancel) { store.send(.dismissError) }
        } message: {
            Text(store.error ?? "")
        }
    }
}

private struct URLEntryStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        Form {
            Section {
                TextField("https://coder.example.com", text: $store.urlInput.sending(\.urlInputChanged))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Coder deployment URL")
            } footer: {
                Text("Enter the URL of your Coder dashboard. Self-hosted deployments are supported.")
            }

            Section {
                Button("Continue") { store.send(.continueWithURLTapped) }
                    .disabled(store.urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

private struct MethodPickerStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        Form {
            Section("How would you like to sign in?") {
                ForEach(Array(store.availableMethods.enumerated()), id: \.offset) { _, method in
                    Button { store.send(.methodTapped(method)) } label: {
                        Label(label(for: method), systemImage: icon(for: method))
                    }
                }
            }
        }
    }

    private func label(for method: AuthMethod) -> String {
        switch method {
        case .password: return "Email & password"
        case .github:   return "Continue with GitHub"
        case let .oidc(text, _): return text
        }
    }

    private func icon(for method: AuthMethod) -> String {
        switch method {
        case .password: return "envelope"
        case .github:   return "person.crop.square.filled.and.at.rectangle"
        case .oidc:     return "key.horizontal"
        }
    }
}

private struct PasswordEntryStep: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        Form {
            Section("Email & password") {
                TextField("Email", text: $store.emailInput.sending(\.emailInputChanged))
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $store.passwordInput.sending(\.passwordInputChanged))
                    .textContentType(.password)
            }

            Section {
                Button("Sign in") { store.send(.submitPasswordTapped) }
                    .disabled(store.emailInput.isEmpty || store.passwordInput.isEmpty)
            }
        }
    }
}

private struct ProgressStep: View {
    let label: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(label).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
