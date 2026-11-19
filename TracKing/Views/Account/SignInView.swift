import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// The first screen when nobody's signed in. Like most well-known apps, it's just the brand and
/// a short stack of equal "Continue with…" buttons; email gets its own screen so this one stays clean.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var isWorking = false
    @State private var message: String?
    @State private var isShowingEmail = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                LogoMark(size: 120)
                Text("TracKing")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.blue)
                Text("Every rep, every rest, every athlete.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = auth.prepareAppleNonce()
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: SignInButtonStyle.height)
                .clipShape(.rect(cornerRadius: SignInButtonStyle.cornerRadius))

                Button {
                    run { try await auth.signInWithGoogle() }
                } label: {
                    SignInButtonLabel(title: "Continue with Google") {
                        // Google's official logo, as their branding guidelines require.
                        Image("GoogleLogo")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                .buttonStyle(SignInButtonStyle(kind: .outlined))

                Button {
                    isShowingEmail = true
                } label: {
                    SignInButtonLabel(title: "Continue with Email") {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .buttonStyle(SignInButtonStyle(kind: .filled))

                Group {
                    if isWorking {
                        ProgressView()
                    } else if let message {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .frame(minHeight: 32)
            }
            .disabled(isWorking)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.screenBackground)
        .sheet(isPresented: $isShowingEmail) {
            EmailSignInView()
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            run {
                try await auth.signInWithApple(idToken: credential.identityToken, fullName: credential.fullName)
            }
        case .failure(let error):
            // Closing the Apple sheet isn't an error worth showing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                message = error.localizedDescription
            }
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await work()
            } catch let error as GIDSignInError where error.code == .canceled {
                // Closing Google's sheet isn't an error worth showing.
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Email

/// Email and password on their own screen: sign in, or switch to creating an account.
private struct EmailSignInView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var isCreating = false
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var isError = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isCreating ? "Create your account" : "Welcome back")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                        Text(isCreating ? "Use the email you'll check for team updates." : "Sign in with your email and password.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        TextField("Email", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(16)
                        Divider().padding(.leading, 16)
                        SecureField(isCreating ? "Password (6+ characters)" : "Password", text: $password)
                            .textContentType(isCreating ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if canSubmit { submit() } }
                            .padding(16)
                    }
                    .background(.background, in: .rect(cornerRadius: 14))

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Text(isCreating ? "Create Account" : "Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SignInButtonStyle(kind: .filled))
                    .disabled(!canSubmit)

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(isError ? .red : .secondary)
                    }

                    if !isCreating {
                        Button("Forgot password?") { resetPassword() }
                            .font(.subheadline.weight(.semibold))
                            .disabled(!email.contains("@") || isWorking)
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.screenBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    withAnimation(.snappy) { isCreating.toggle() }
                    message = nil
                } label: {
                    Text(isCreating ? "Already have an account? **Sign in**" : "New to TracKing? **Create an account**")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .tint(.primary)
                .background(Color.screenBackground)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focusedField = .email }
        }
    }

    private func submit() {
        focusedField = nil
        run {
            if isCreating {
                try await auth.createUser(email: email, password: password)
            } else {
                try await auth.signIn(email: email, password: password)
            }
            // Signed in: the app moves on to account setup or the tabs.
            dismiss()
        }
    }

    private func resetPassword() {
        run {
            try await auth.sendPasswordReset(to: email)
            isError = false
            message = "Check \(email) for a link to reset your password."
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await work()
            } catch {
                isError = true
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Buttons

/// The inside of a sign-in button: a logo and "Continue with…", matching Apple's button.
private struct SignInButtonLabel<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-width buttons the same height and shape as Sign in with Apple, so every option
/// carries equal weight.
private struct SignInButtonStyle: ButtonStyle {
    enum Kind {
        /// White with a hairline border, for Google.
        case outlined
        /// The app's blue, for email.
        case filled
    }

    static let height: CGFloat = 54
    static let cornerRadius: CGFloat = 14

    let kind: Kind

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(kind == .filled ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(kind == .filled ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(.background))
            }
            .overlay {
                if kind == .outlined {
                    RoundedRectangle(cornerRadius: Self.cornerRadius)
                        .strokeBorder(.separator, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
    }
}

#Preview {
    SignInView()
        .environment(AuthModel())
}

#Preview("Email") {
    EmailSignInView()
        .environment(AuthModel())
}
