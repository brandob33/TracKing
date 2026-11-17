import SwiftUI
import SwiftData

/// The opening screen, shown once: are you coaching or are you an athlete? An athlete also
/// gives their name and group, so their workouts and times are theirs from the start.
struct WelcomeView: View {
    @Bindable var athlete: Athlete
    let onFinish: (AppRole) -> Void

    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @State private var choice: AppRole?
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        athlete.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    LogoMark(size: 96)
                    Text("Welcome to TracKing")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text("How will you use the app?")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    RoleButton(
                        title: "I'm coaching",
                        detail: "Time every group, start rests, and see results.",
                        systemImage: "stopwatch.fill",
                        isSelected: choice == .coach
                    ) {
                        choice = .coach
                        isNameFocused = false
                    }
                    RoleButton(
                        title: "I'm an athlete",
                        detail: "See your workout, log your times, and track your bests.",
                        systemImage: "figure.run",
                        isSelected: choice == .athlete
                    ) {
                        choice = .athlete
                    }
                }

                if choice == .athlete {
                    athleteForm
                }

                if let choice {
                    Button {
                        athlete.name = trimmedName
                        onFinish(choice)
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.finishFill)
                    .disabled(choice == .athlete && trimmedName.isEmpty)

                    Text("You can switch later from the \(choice == .coach ? "Team" : "Profile") tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .animation(.snappy, value: choice)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.screenBackground)
    }

    private var athleteForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your name")
                    .font(.subheadline.weight(.semibold))
                TextField("First and last name", text: $athlete.name)
                    .textContentType(.name)
                    .focused($isNameFocused)
                    .padding(12)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Men or women")
                    .font(.subheadline.weight(.semibold))
                Picker("Men or women", selection: $athlete.genderGroupID) {
                    ForEach(TrainingGroup.genderGroups) { group in
                        Text(group.name).tag(group.id)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Event group")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Event group", selection: $athlete.eventGroupID) {
                    ForEach(groups) { group in
                        Text(group.name).tag(group.groupID)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Your group decides which sets and goal times you see. Your coach can change it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.cardBackground, in: .rect(cornerRadius: 20))
    }
}

/// One of the two big choices on the opening screen.
private struct RoleButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(Theme.blue)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: .rect(cornerRadius: 20))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.blue, lineWidth: 2)
                }
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let container = SampleData.previewContainer
    let athlete = Athlete(isDeviceUser: true)
    container.mainContext.insert(athlete)
    return WelcomeView(athlete: athlete) { _ in }
        .modelContainer(container)
}
