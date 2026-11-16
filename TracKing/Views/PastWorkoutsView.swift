import SwiftUI
import SwiftData

/// Sessions up to today, grouped by training week, newest first.
struct PastWorkoutsView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Environment(\.athleteProfile) private var profile
    @State private var filter = Filter.logged

    enum Filter: String, CaseIterable, Identifiable {
        case logged = "Logged"
        case all = "All"
        var id: Self { self }
    }

    private var pastWorkouts: [Workout] {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return workouts.filter { workout in
            workout.date < endOfToday && (filter == .all || workout.loggedRepCount(for: profile) > 0)
        }
    }

    /// Workouts grouped by the week they belong to, newest week first.
    private var weekGroups: [WeekGroup] {
        let grouped = Dictionary(grouping: pastWorkouts) { workout in
            workout.week?.startDate ?? Calendar.current.startOfDay(for: workout.date)
        }
        return grouped
            .map { WeekGroup(startDate: $0.key, week: $0.value.first?.week, workouts: $0.value) }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(weekGroups) { group in
                    Section {
                        ForEach(group.workouts) { workout in
                            NavigationLink(value: workout) {
                                PastWorkoutRow(workout: workout)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Week of \(group.startDate.formatted(.dateTime.month(.abbreviated).day()))")
                            if let week = group.week {
                                Text(week.cycleSummary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .overlay {
                if weekGroups.isEmpty {
                    ContentUnavailableView(
                        filter == .logged ? "No Logged Workouts" : "No Past Workouts",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(filter == .logged
                            ? "Times you log on a workout will show up here."
                            : "Workouts from earlier days will show up here.")
                    )
                }
            }
            .navigationTitle("Past Workouts")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                PastWorkoutDetailView(workout: workout)
            }
        }
    }
}

private struct WeekGroup: Identifiable {
    let startDate: Date
    let week: TrainingWeek?
    let workouts: [Workout]
    var id: Date { startDate }
}

private struct PastWorkoutRow: View {
    let workout: Workout

    @Environment(\.athleteProfile) private var profile

    var body: some View {
        let sets = workout.visibleSets(for: profile)
        let totalReps = sets.reduce(0) { $0 + $1.totalReps }
        let loggedReps = workout.loggedRepCount(for: profile)

        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(workout.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(workout.date, format: .dateTime.day())
                    .font(.title3.bold())
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                if totalReps == 0 {
                    Text("No timed reps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if loggedReps == 0 {
                    Text("Not logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(loggedReps) of \(totalReps) reps logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

/// A read-only summary of a past session: every rep's logged time next to its goal.
struct PastWorkoutDetailView: View {
    let workout: Workout

    @Environment(\.athleteProfile) private var profile

    var body: some View {
        let sets = workout.visibleSets(for: profile)

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(workout.title)
                        .font(.title2.bold())
                }
                .padding(.vertical, 4)

                if sets.isEmpty {
                    Text("This session didn't have any timed reps.")
                        .foregroundStyle(.secondary)
                } else {
                    SummaryStats(sets: sets, profile: profile)
                }
            }

            ForEach(sets) { workoutSet in
                Section {
                    ForEach(1...workoutSet.totalReps, id: \.self) { repNumber in
                        RepResultRow(workoutSet: workoutSet, repNumber: repNumber)
                    }
                } header: {
                    Text(workoutSet.summary)
                }
            }
        }
        .navigationTitle("Session \(workout.sessionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: EditTimesRoute(workout: workout)) {
                    Label("Edit Times", systemImage: "pencil")
                }
            }
        }
        .navigationDestination(for: EditTimesRoute.self) { route in
            WorkoutDetailView(workout: route.workout)
        }
    }
}

/// Navigation value for opening a past workout to edit its logged times.
private struct EditTimesRoute: Hashable {
    let workout: Workout
}

/// Counts of logged reps and how they compare to the goals.
private struct SummaryStats: View {
    let sets: [WorkoutSet]
    let profile: AthleteProfile

    var body: some View {
        let totalReps = sets.reduce(0) { $0 + $1.totalReps }
        let comparisons = sets.flatMap { workoutSet in
            workoutSet.results(forAthlete: profile.athleteID).compactMap { result in
                profile.bestMatch(in: workoutSet.targets, groupID: \.groupID)?.compare(result.seconds)
            }
        }
        let loggedReps = sets.reduce(0) { $0 + $1.results(forAthlete: profile.athleteID).count }

        HStack {
            StatTile(value: "\(loggedReps)/\(totalReps)", label: "Logged")
            StatTile(value: "\(comparisons.filter { $0 == .onTarget }.count)", label: "On Target", color: .green)
            StatTile(value: "\(comparisons.filter { if case .faster = $0 { true } else { false } }.count)", label: "Faster", color: .blue)
            StatTile(value: "\(comparisons.filter { if case .slower = $0 { true } else { false } }.count)", label: "Slower", color: .orange)
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// One rep's logged time, its goal, and how far off the goal it was.
private struct RepResultRow: View {
    let workoutSet: WorkoutSet
    let repNumber: Int

    @Environment(\.athleteProfile) private var profile

    var body: some View {
        let target = profile.bestMatch(in: workoutSet.targets, groupID: \.groupID)
        let result = workoutSet.result(forRep: repNumber, athleteID: profile.athleteID)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutSet.repName)
                    .fontWeight(.medium)
                if workoutSet.setCount > 1 {
                    Text("Set \(workoutSet.setNumber(forRep: repNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let result {
                    Text(TimeFormatting.raceTime(result.seconds, fractionDigits: 2))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                }
                if let target {
                    Text("Goal \(target.goalText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let result, let target {
                ComparisonBadge(comparison: target.compare(result.seconds))
            }
        }
    }
}

private struct ComparisonBadge: View {
    let comparison: GoalComparison

    var body: some View {
        let (text, color): (String, Color) = switch comparison {
        case .faster(let by): ("−" + TimeFormatting.compactDelta(by), .blue)
        case .onTarget: ("✓", .green)
        case .slower(let by): ("+" + TimeFormatting.compactDelta(by), .orange)
        }

        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(minWidth: 48)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: .capsule)
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch comparison {
        case .faster(let by): "\(TimeFormatting.compactDelta(by)) seconds faster than goal"
        case .onTarget: "On target"
        case .slower(let by): "\(TimeFormatting.compactDelta(by)) seconds slower than goal"
        }
    }
}

extension TimeFormatting {
    /// A difference from the goal in seconds, e.g. "0.32".
    static func compactDelta(_ seconds: Double) -> String {
        seconds.formatted(.number.precision(.fractionLength(2)))
    }
}

#Preview {
    let container = SampleData.previewContainer
    // Log a few times on last week's Tuesday so the list has something to show.
    let tuesdays = (try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    )) ?? []
    if let workout = tuesdays.first, workout.loggedRepCount(for: .sample) == 0 {
        let sets = workout.visibleSets(for: .sample)
        sets.first?.results.append(RepResult(repNumber: 1, seconds: 15.8, athleteID: AthleteProfile.sample.athleteID))
        sets.first?.results.append(RepResult(repNumber: 2, seconds: 16.4, athleteID: AthleteProfile.sample.athleteID))
        sets.dropFirst().first?.results.append(RepResult(repNumber: 1, seconds: 9.6, athleteID: AthleteProfile.sample.athleteID))
    }
    return PastWorkoutsView()
        .modelContainer(container)
}

#Preview("Summary") {
    let container = SampleData.previewContainer
    let workout = try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    if let workout, workout.loggedRepCount(for: .sample) == 0 {
        let sets = workout.visibleSets(for: .sample)
        sets.first?.results.append(RepResult(repNumber: 1, seconds: 15.8, athleteID: AthleteProfile.sample.athleteID))
        sets.first?.results.append(RepResult(repNumber: 2, seconds: 16.4, athleteID: AthleteProfile.sample.athleteID))
        sets.dropFirst().first?.results.append(RepResult(repNumber: 1, seconds: 9.6, athleteID: AthleteProfile.sample.athleteID))
    }
    return NavigationStack {
        if let workout {
            PastWorkoutDetailView(workout: workout)
        }
    }
    .modelContainer(container)
}
