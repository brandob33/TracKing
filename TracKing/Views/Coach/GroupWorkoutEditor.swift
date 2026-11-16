import SwiftUI
import SwiftData

/// The coach's editor for one event group's part of a session: its start time, note, and sets.
struct GroupWorkoutEditor: View {
    let group: EventGroup
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @State private var editorRoute: SetEditorRoute?

    private var groupSets: [WorkoutSet] {
        group.sets(in: workout)
    }

    /// Sets with no group, which every athlete sees.
    private var sharedSets: [WorkoutSet] {
        workout.orderedUnits.flatMap { unit in
            unit.orderedSets.filter { $0.groupID == nil }
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(workout.title)
                        .font(.title3.bold())
                }
            }

            Section {
                Toggle("Own Start Time", isOn: hasOwnStartTime)
                if workout.startTime(forGroup: group.groupID) != nil {
                    DatePicker("Start Time", selection: startTime, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Without one, \(group.name) athletes see the session's general start time.")
            }

            Section("Note for \(group.name)") {
                TextField("Optional", text: note, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                ForEach(groupSets) { workoutSet in
                    Button {
                        editorRoute = .edit(workoutSet)
                    } label: {
                        CoachSetRow(workoutSet: workoutSet)
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let sets = groupSets
                    for index in offsets {
                        modelContext.delete(sets[index])
                    }
                }

                Button("Add Set", systemImage: "plus") {
                    editorRoute = .new
                }
            } header: {
                Text("\(group.name) Sets")
            } footer: {
                if groupSets.isEmpty {
                    Text("Add the reps this group should run, with goal times for men and women.")
                }
            }

            if !sharedSets.isEmpty {
                Section {
                    ForEach(sharedSets) { workoutSet in
                        CoachSetRow(workoutSet: workoutSet)
                    }
                } header: {
                    Text("For Every Group")
                } footer: {
                    Text("These sets are shown to all athletes.")
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editorRoute) { route in
            switch route {
            case .new:
                SetEditorView(workout: workout, groupID: group.groupID, existing: nil)
            case .edit(let workoutSet):
                SetEditorView(workout: workout, groupID: group.groupID, existing: workoutSet)
            }
        }
    }

    // MARK: Bindings into the workout

    private var hasOwnStartTime: Binding<Bool> {
        Binding {
            workout.startTime(forGroup: group.groupID) != nil
        } set: { isOn in
            // Start from the session's general time so the picker opens somewhere sensible.
            let general = workout.orderedUnits.lazy.compactMap { $0.startTimes.first { $0.groupID == nil } }.first
            let time = GroupStartTime(groupID: group.groupID, hour: general?.hour ?? 15, minute: general?.minute ?? 0)
            workout.setStartTime(isOn ? time : nil, forGroup: group.groupID)
        }
    }

    private var startTime: Binding<Date> {
        Binding {
            workout.startTime(forGroup: group.groupID)?.date(on: workout.date) ?? workout.date
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            workout.setStartTime(
                GroupStartTime(groupID: group.groupID, hour: components.hour ?? 0, minute: components.minute ?? 0),
                forGroup: group.groupID
            )
        }
    }

    private var note: Binding<String> {
        Binding {
            workout.note(forGroup: group.groupID)
        } set: { text in
            workout.setNote(text, forGroup: group.groupID)
        }
    }
}

/// Which set the editor sheet is showing.
private enum SetEditorRoute: Identifiable, Hashable {
    case new
    case edit(WorkoutSet)

    var id: Self { self }
}

/// A set as the coach sees it: the prescription, rest, and every goal time.
private struct CoachSetRow: View {
    let workoutSet: WorkoutSet

    private var goals: String? {
        guard !workoutSet.targets.isEmpty else { return nil }
        return workoutSet.targets.map { target in
            let who = switch target.groupID {
            case TrainingGroup.men.id: "M"
            case TrainingGroup.women.id: "W"
            default: "Goal"
            }
            return "\(who) \(target.goalText)"
        }
        .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workoutSet.summary)
                .fontWeight(.medium)
            HStack(spacing: 12) {
                if workoutSet.restSeconds > 0 {
                    Label(TimeFormatting.rest(workoutSet.restSeconds), systemImage: "timer")
                }
                if let goals {
                    Label(goals, systemImage: "flag.checkered")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = SampleData.previewContainer
    let context = container.mainContext
    let workout = try? context.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    let group = try? context.fetch(FetchDescriptor<EventGroup>(sortBy: [SortDescriptor(\.order)])).first
    NavigationStack {
        if let workout, let group {
            GroupWorkoutEditor(group: group, workout: workout)
        }
    }
    .modelContainer(container)
}
