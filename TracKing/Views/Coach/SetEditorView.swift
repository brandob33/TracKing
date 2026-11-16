import SwiftUI
import SwiftData

/// A sheet where the coach creates or edits one set for an event group. Changes are kept in a
/// draft and only written to the workout on Save, so Cancel discards them.
struct SetEditorView: View {
    let workout: Workout
    let groupID: String
    /// The set being edited, or `nil` to create a new one.
    let existing: WorkoutSet?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SetDraft

    init(workout: Workout, groupID: String, existing: WorkoutSet?) {
        self.workout = workout
        self.groupID = groupID
        self.existing = existing
        _draft = State(initialValue: existing.map(SetDraft.init(from:)) ?? SetDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reps") {
                    TextField("Label, e.g. SS or Accelerations", text: $draft.label)
                    Stepper("Sets: \(draft.setCount)", value: $draft.setCount, in: 1...20)
                    Stepper("Reps: \(draft.reps)", value: $draft.reps, in: 1...50)
                    NumberField(title: "Distance", unit: "m", text: $draft.distanceText)
                    NumberField(title: "Intensity", unit: "%", text: $draft.intensityText)
                    TextField("Surface, e.g. Grass or Track", text: $draft.surface)
                }

                Section {
                    TimeField(title: "Between Reps", prompt: "e.g. 4:00", text: $draft.restText)
                    if draft.setCount > 1 {
                        TimeField(title: "Between Sets", prompt: "e.g. 8:00", text: $draft.setRestText)
                    }
                } header: {
                    Text("Rest")
                }

                Section {
                    Picker("Goal Times", selection: $draft.goalMode) {
                        ForEach(GoalMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch draft.goalMode {
                    case .none:
                        EmptyView()
                    case .same:
                        TargetFields(target: $draft.everyone)
                    case .separate:
                        TargetFields(title: "Men", target: $draft.men)
                        TargetFields(title: "Women", target: $draft.women)
                    }
                } header: {
                    Text("Goal Times")
                } footer: {
                    Text(draft.goalMode.footer)
                }

                Section("Notes") {
                    TextField("Optional", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(existing == nil ? "New Set" : "Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    private func save() {
        if let existing {
            draft.apply(to: existing)
        } else {
            let unit = workout.runningUnit()
            let nextOrder = (unit.sets.map(\.order).max() ?? -1) + 1
            let workoutSet = WorkoutSet(order: nextOrder, reps: draft.reps, groupID: groupID)
            draft.apply(to: workoutSet)
            unit.sets.append(workoutSet)
        }
    }
}

// MARK: - Draft

/// Whether a set has goal times, and whether men and women share them.
enum GoalMode: CaseIterable {
    case none
    case same
    case separate

    var title: String {
        switch self {
        case .none: "None"
        case .same: "Same"
        case .separate: "Men & Women"
        }
    }

    var footer: String {
        switch self {
        case .none: "Athletes can still log times without a goal."
        case .same: "Men and women share one goal time."
        case .separate: "Men and women each get their own goal. Leave one blank for no goal."
        }
    }
}

/// The text fields for one goal time. Times are typed the way athletes enter them, e.g. "16.0" or "1:08.4".
struct TargetDraft: Equatable {
    var goalText = ""
    var maxText = ""
    var paceText = ""

    init() {}

    init(_ target: GroupTarget?) {
        guard let target else { return }
        goalText = TimeFormatting.compact(target.goalSeconds)
        maxText = target.goalMaxSeconds.map(TimeFormatting.compact) ?? ""
        paceText = target.pacePer100.map(TimeFormatting.compact) ?? ""
    }

    var isValid: Bool {
        guard !goalText.isBlank else {
            // A range or pace without a goal doesn't mean anything.
            return maxText.isBlank && paceText.isBlank
        }
        guard let goal = TimeFormatting.parse(goalText) else { return false }
        if !maxText.isBlank {
            guard let max = TimeFormatting.parse(maxText), max > goal else { return false }
        }
        if !paceText.isBlank, TimeFormatting.parse(paceText) == nil {
            return false
        }
        return true
    }

    /// The goal for a group, or `nil` when the goal is left blank.
    func target(for groupID: String?) -> GroupTarget? {
        guard let goal = TimeFormatting.parse(goalText) else { return nil }
        return GroupTarget(
            groupID: groupID,
            pacePer100: TimeFormatting.parse(paceText),
            goalSeconds: goal,
            goalMaxSeconds: TimeFormatting.parse(maxText)
        )
    }
}

/// An editable copy of a `WorkoutSet`, using text for the optional number fields.
struct SetDraft {
    var label = ""
    var setCount = 1
    var reps = 1
    var distanceText = ""
    var intensityText = ""
    var surface = ""
    var restText = ""
    var setRestText = ""
    var notes = ""
    var goalMode = GoalMode.none
    var everyone = TargetDraft()
    var men = TargetDraft()
    var women = TargetDraft()

    init() {}

    init(from workoutSet: WorkoutSet) {
        label = workoutSet.label
        setCount = max(workoutSet.setCount, 1)
        reps = max(workoutSet.reps, 1)
        distanceText = workoutSet.distanceMeters.map(String.init) ?? ""
        intensityText = workoutSet.intensityPercent.map(String.init) ?? ""
        surface = workoutSet.surface
        restText = workoutSet.restSeconds > 0 ? TimeFormatting.rest(workoutSet.restSeconds) : ""
        setRestText = workoutSet.setRestSeconds > 0 ? TimeFormatting.rest(workoutSet.setRestSeconds) : ""
        notes = workoutSet.notes

        let targets = workoutSet.targets
        let menTarget = targets.first { $0.groupID == TrainingGroup.men.id }
        let womenTarget = targets.first { $0.groupID == TrainingGroup.women.id }
        if menTarget != nil || womenTarget != nil {
            goalMode = .separate
            men = TargetDraft(menTarget)
            women = TargetDraft(womenTarget)
        } else if let shared = targets.first {
            goalMode = .same
            everyone = TargetDraft(shared)
        }
    }

    var isValid: Bool {
        let numbersValid = [distanceText, intensityText].allSatisfy { $0.isBlank || Int($0) != nil }
        let restValid = [restText, setRestText].allSatisfy { $0.isBlank || TimeFormatting.parse($0) != nil }
        let goalsValid = switch goalMode {
        case .none: true
        case .same: everyone.isValid
        case .separate: men.isValid && women.isValid
        }
        return numbersValid && restValid && goalsValid
    }

    func apply(to workoutSet: WorkoutSet) {
        workoutSet.label = label.trimmingCharacters(in: .whitespaces)
        workoutSet.setCount = setCount
        workoutSet.reps = reps
        workoutSet.distanceMeters = Int(distanceText)
        workoutSet.intensityPercent = Int(intensityText)
        workoutSet.surface = surface.trimmingCharacters(in: .whitespaces)
        workoutSet.restSeconds = Self.seconds(restText)
        workoutSet.setRestSeconds = setCount > 1 ? Self.seconds(setRestText) : 0
        workoutSet.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        workoutSet.targets = switch goalMode {
        case .none: []
        case .same: [everyone.target(for: nil)].compactMap(\.self)
        case .separate: [men.target(for: TrainingGroup.men.id), women.target(for: TrainingGroup.women.id)].compactMap(\.self)
        }
    }

    /// Rest typed as "4:00" or "90", in whole seconds.
    private static func seconds(_ text: String) -> Int {
        TimeFormatting.parse(text).map { Int($0.rounded()) } ?? 0
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Fields

/// A whole-number field with a unit, e.g. "Distance ___ m".
private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var text: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, text: $text, prompt: Text("—"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A time field typed like "4:00" or "16.5".
private struct TimeField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text, prompt: Text(prompt))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

/// Goal, optional upper end of a range, and optional pace per 100m.
private struct TargetFields: View {
    var title: String?
    @Binding var target: TargetDraft

    var body: some View {
        if let title {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        TimeField(title: "Goal", prompt: "e.g. 16.0", text: $target.goalText)
        TimeField(title: "Up To (Range)", prompt: "Optional", text: $target.maxText)
        TimeField(title: "Pace /100m", prompt: "Optional", text: $target.paceText)
    }
}

#Preview {
    let container = SampleData.previewContainer
    let workout = try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    if let workout {
        SetEditorView(workout: workout, groupID: TrainingGroup.shortSprint.id, existing: workout.visibleSets(for: .sample).first)
            .modelContainer(container)
    }
}
