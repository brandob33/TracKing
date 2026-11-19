import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

/// The first screen when nobody's signed in: Sign in with Apple, or email and password.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var message: String?
    @FocusState private var focusedField: Field?

    enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case create = "Create Account"
    }

    enum Field {
        case email, password
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    LogoMark(size: 96)
                    Text("TracKing")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.blue)
                    Text("Workouts, times, and rest for your whole team.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = auth.prepareAppleNonce()
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: 12))

                // Google's own button, as their branding guidelines ask.
                GoogleSignInButton(
                    viewModel: GoogleSignInButtonViewModel(scheme: colorScheme == .dark ? .dark : .light, style: .wide, state: isWorking ? .disabled : .normal)
                ) {
                    run { try await auth.signInWithGoogle() }
                }
                .frame(height: 52)

                HStack {
                    VStack { Divider() }
                    Text("or use email")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    VStack { Divider() }
                }

                VStack(spacing: 12) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(14)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 12))

                    SecureField(mode == .create ? "Password (6+ characters)" : "Password", text: $password)
                        .textContentType(mode == .create ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { submit() } }
                        .padding(14)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 12))

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.blue)
                    .disabled(!canSubmit)

                    if mode == .signIn {
                        Button("Forgot Password?") { resetPassword() }
                            .font(.subheadline)
                            .disabled(!email.contains("@") || isWorking)
                    }
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.screenBackground)
        .onChange(of: mode) { message = nil }
    }

    private func submit() {
        focusedField = nil
        run {
            switch mode {
            case .signIn: try await auth.signIn(email: email, password: password)
            case .create: try await auth.createUser(email: email, password: password)
            }
        }
    }

    private func resetPassword() {
        run {
            try await auth.sendPasswordReset(to: email)
            message = "Check \(email) for a link to reset your password."
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

#Preview {
    SignInView()
        .environment(AuthModel())
}
