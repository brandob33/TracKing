import SwiftUI

/// Shown once, right after someone first signs in: their name and whether they're a coach
/// or an athlete, then creating or joining a team. The account type sets which tabs they get.
struct AccountSetupView: View {
    @Environment(AuthModel.self) private var auth

    @State private var name = ""
    @State private var role: AppRole?
    @State private var isWorking = false
    @State private var message: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if auth.account == nil {
                accountStep
            } else {
                // Account saved: create or join a team, or skip for now.
                TeamSetupView(onDone: auth.finishSetup)
            }
        }
        .background(Color.screenBackground)
        .onAppear {
            if name.isEmpty { name = auth.suggestedName }
        }
    }

    private var accountStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    LogoMark(size: 72)
                    Text("Set Up Your Account")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("This can't be changed later, so pick the one that fits.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .font(.title3)
                    .padding(14)
                    .background(.background, in: .rect(cornerRadius: 12))

                VStack(spacing: 12) {
                    RoleChoice(
                        title: "I'm a coach",
                        detail: "Create a team, write workouts, and time every group.",
                        systemImage: "stopwatch.fill",
                        isSelected: role == .coach
                    ) { role = .coach }
                    RoleChoice(
                        title: "I'm an athlete",
                        detail: "Join your team, see your workouts, and log your times.",
                        systemImage: "figure.run",
                        isSelected: role == .athlete
                    ) { role = .athlete }
                }

                Button {
                    save()
                } label: {
                    Group {
                        if isWorking { ProgressView() } else { Text("Continue") }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.blue)
                .disabled(trimmedName.isEmpty || role == nil || isWorking)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Sign Out", role: .destructive) { auth.signOut() }
                    .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func save() {
        guard let role else { return }
        isWorking = true
        message = nil
        Task {
            do {
                try await auth.createAccount(name: trimmedName, role: role)
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

/// Create a team (coaches) or join one with a code (athletes). Used during setup, and later
/// from the Team or Profile tab for anyone who skipped it.
struct TeamSetupView: View {
    let onDone: () -> Void

    @Environment(AuthModel.self) private var auth
    @State private var text = ""
    @State private var isWorking = false
    @State private var message: String?

    private var isCoach: Bool { auth.account?.role == .coach }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: isCoach ? "person.3.fill" : "person.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.blue)
                    Text(isCoach ? "Create Your Team" : "Join Your Team")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(isCoach
                         ? "You'll get a code to share with your athletes."
                         : "Ask your coach for the team's 6-character code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                TextField(isCoach ? "Team name, e.g. UCI Sprints & Hurdles" : "Team code", text: $text)
                    .font(isCoach ? .title3 : .system(.title2, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(isCoach ? .leading : .center)
                    .textInputAutocapitalization(isCoach ? .words : .characters)
                    .autocorrectionDisabled(!isCoach)
                    .padding(14)
                    .background(.background, in: .rect(cornerRadius: 12))
                    .onChange(of: text) { _, newValue in
                        // Codes are six characters; keep typing tidy.
                        if !isCoach, newValue.count > 6 { text = String(newValue.prefix(6)) }
                    }

                Button {
                    submit()
                } label: {
                    Group {
                        if isWorking { ProgressView() } else { Text(isCoach ? "Create Team" : "Join Team") }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.blue)
                .disabled(isWorking || (isCoach ? trimmed.isEmpty : trimmed.count != 6))

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Not Now", action: onDone)
                    .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.screenBackground)
    }

    private func submit() {
        isWorking = true
        message = nil
        Task {
            do {
                if isCoach {
                    try await auth.createTeam(named: trimmed)
                } else {
                    try await auth.joinTeam(code: trimmed)
                }
                onDone()
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

/// A big tappable card for picking coach or athlete.
private struct RoleChoice: View {
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.blue))
                    .frame(width: 48, height: 48)
                    .background(isSelected ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(Theme.blue.opacity(0.12)), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(.tertiary))
            }
            .padding(14)
            .background(.background, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.blue : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AccountSetupView()
        .environment(AuthModel())
}
