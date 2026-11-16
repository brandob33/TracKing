import SwiftUI
import SwiftData

/// One event group: its name, its athletes, and its plan for each session, week by week.
struct EventGroupDetailView: View {
    @Bindable var group: EventGroup

    @Query(sort: \TrainingWeek.startDate) private var weeks: [TrainingWeek]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]

    private var groupAthletes: [Athlete] {
        athletes.filter { $0.eventGroupID == group.groupID }
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Group Name", text: $group.name)
            }

            Section("Athletes") {
                if groupAthletes.isEmpty {
                    Text("No athletes yet. Assign athletes from the roster.")
                        .foregroundStyle(.secondary)
                }
                ForEach(groupAthletes) { athlete in
                    NavigationLink {
                        AthleteAssignmentView(athlete: athlete)
                    } label: {
                        LabeledContent(
                            athlete.name.isEmpty ? "Unnamed Athlete" : athlete.name,
                            value: TrainingGroup.name(for: athlete.genderGroupID)
                        )
                    }
                }
            }

            ForEach(weeks) { week in
                Section {
                    ForEach(week.workouts.sorted { $0.date < $1.date }) { workout in
                        NavigationLink {
                            GroupWorkoutEditor(group: group, workout: workout)
                        } label: {
                            GroupWorkoutRow(group: group, workout: workout)
                        }
                    }
                } header: {
                    Text("Week of \(week.startDate.formatted(.dateTime.month(.abbreviated).day()))")
                } footer: {
                    Text(week.cycleSummary)
                }
            }
        }
        .navigationTitle(group.name.isEmpty ? "Event Group" : group.name)
    }
}

/// A session in the group's schedule: the day, title, and how much is planned for this group.
private struct GroupWorkoutRow: View {
    let group: EventGroup
    let workout: Workout

    private var setCount: Int {
        group.sets(in: workout).count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(workout.title)
                    .fontWeight(.medium)
            }
            Spacer()
            Text(setCount == 0 ? "No sets" : setCount == 1 ? "1 set" : "\(setCount) sets")
                .font(.subheadline)
                .foregroundStyle(setCount == 0 ? .tertiary : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = SampleData.previewContainer
    let group = try? container.mainContext.fetch(FetchDescriptor<EventGroup>(sortBy: [SortDescriptor(\.order)])).first
    NavigationStack {
        if let group {
            EventGroupDetailView(group: group)
        }
    }
    .modelContainer(container)
}
