import SwiftUI
import SwiftData

/// The coach's Workout tab: the day's session as a Track Board for timing every group at once,
/// or as the full plan with warm-ups, drills, and notes.
struct CoachWorkoutView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames

    @State private var date: Date
    @State private var mode = Mode.timing
    @State private var planSessionID: String?
    @State private var isCombining = false

    enum Mode: String, CaseIterable {
        case timing = "Timing"
        case plan = "Plan"
    }

    private let calendar = Calendar.current

    init(initialDate: Date = .now) {
        _date = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var workout: Workout? {
        workouts.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        let sessions = workout.map { GroupSession.all(in: $0, groups: groups, athletes: athletes) } ?? []

        NavigationStack {
            VStack(spacing: 0) {
                DayHeader(date: $date, workout: workout)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if let workout {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    switch mode {
                    case .timing:
                        TrackBoardView(workout: workout, sessions: sessions)
                    case .plan:
                        planView(sessions: sessions)
                    }
                } else {
                    ContentUnavailableView(
                        "No Session",
                        systemImage: "calendar.badge.minus",
                        description: Text("Nothing is scheduled for this day.")
                    )
                    .frame(maxHeight: .infinity)
                }
            }
            .background(Color.screenBackground)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SeriesRoute.self) { route in
                SeriesDetailView(name: route.name)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Combine Groups", systemImage: "rectangle.stack.badge.plus") {
                        isCombining = true
                    }
                    .disabled(workout == nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    RoleSwitchButton(to: .athlete)
                }
            }
            .sheet(isPresented: $isCombining) {
                if let workout {
                    CombineGroupsSheet(workout: workout, groups: groups)
                }
            }
        }
        .onAppear { board.workoutTitle = workout?.title ?? "" }
        .onChange(of: date) { board.workoutTitle = workout?.title ?? "" }
    }

    /// The full plan for one group, picked from a menu, so warm-ups and notes are a tap away.
    @ViewBuilder
    private func planView(sessions: [GroupSession]) -> some View {
        let index = sessions.firstIndex { $0.id == planSessionID } ?? 0
        if sessions.indices.contains(index) {
            let session = sessions[index]
            VStack(spacing: 0) {
                Picker("Group", selection: Binding(get: { session.id }, set: { planSessionID = $0 })) {
                    ForEach(sessions) { Text($0.title(eventGroupNames: eventGroupNames)).tag($0.id) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                CoachGroupSessionView(
                    session: session,
                    restTimer: board.restBinding(for: session, label: session.label(colorIndex: index, eventGroupNames: eventGroupNames))
                )
                .id(session.id)
            }
        } else {
            ContentUnavailableView("No Groups", systemImage: "person.3", description: Text("No athletes are running in this session."))
                .frame(maxHeight: .infinity)
        }
    }
}

extension GroupSession {
    /// e.g. "Short Sprints + Short Hurdles", or a day group's name like "Brandon & Justin".
    func title(eventGroupNames: [String: String]) -> String {
        if let dayGroup {
            return dayGroup.name
        }
        return groupIDs.map { TrainingGroup.name(for: $0, eventGroupNames: eventGroupNames) }.joined(separator: " + ")
    }
}

/// Identifies one athlete's time field for one rep, for keyboard focus.
struct AthleteRepKey: Hashable {
    let rep: RepKey
    let athleteID: String
}

// MARK: - Header

/// Day navigation and the session's title.
private struct DayHeader: View {
    @Binding var date: Date
    let workout: Workout?

    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Button("Previous Day", systemImage: "chevron.left") { moveDay(by: -1) }
            Spacer()
            VStack(spacing: 2) {
                Text(workout?.title ?? "No Session")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(calendar.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                        .foregroundStyle(.tint)
                    Text(date, format: .dateTime.month(.abbreviated).day())
                    if let focus = workout?.week?.focus, !focus.isEmpty {
                        FocusBadge(text: focus)
                    }
                }
                .font(.caption.weight(.semibold))
                if !calendar.isDateInToday(date) {
                    Button("Back to Today") {
                        date = calendar.startOfDay(for: .now)
                    }
                    .font(.caption)
                }
            }
            Spacer()
            Button("Next Day", systemImage: "chevron.right") { moveDay(by: 1) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity)
    }

    private func moveDay(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: date) {
            date = newDate
        }
    }
}

/// A sheet for picking which groups run together this session.
private struct CombineGroupsSheet: View {
    let workout: Workout
    let groups: [EventGroup]

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    var body: some View {
        NavigationStack {
            List(groups, selection: $selection) { group in
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                    if let partners = partnerNames(for: group) {
                        Text("Now with \(partners)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(group.groupID)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Combine Groups")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text("Pick the groups running the same workout on \(workout.date.formatted(.dateTime.weekday(.wide))). They'll share one timing screen, and everyone runs every set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Combine") {
                        workout.combine(groups.map(\.groupID).filter { selection.contains($0) })
                        dismiss()
                    }
                    .disabled(selection.count < 2)
                }
            }
        }
    }

    /// The other groups this one is already combined with, if any.
    private func partnerNames(for group: EventGroup) -> String? {
        guard let combination = workout.groupCombinations.first(where: { $0.groupIDs.contains(group.groupID) }) else { return nil }
        let names = groups.filter { $0.groupID != group.groupID && combination.groupIDs.contains($0.groupID) }.map(\.name)
        return names.isEmpty ? nil : names.formatted(.list(type: .and))
    }
}

// MARK: - Plan

/// One group's whole plan for the day: warm-ups, drills, notes, and every set, with each rep
/// opening the stopwatch to review, fix, or retime its times.
struct CoachGroupSessionView: View {
    let session: GroupSession
    @Binding var restTimer: RestTimer?

    /// The rep open in the stopwatch.
    @State private var timingRep: TimingRep?

    private var workout: Workout { session.workout }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(workout.title)
                        .font(.title2.bold())
                    HStack(spacing: 16) {
                        if let startTime = session.startTime {
                            Label {
                                Text(startTime, format: .dateTime.hour().minute())
                            } icon: {
                                Image(systemName: "clock")
                            }
                        }
                        Label(session.athletes.count == 1 ? "1 athlete" : "\(session.athletes.count) athletes", systemImage: "person.2.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            ForEach(workout.orderedUnits) { unit in
                UnitInfoSection(unit: unit, number: unit.order + 1, day: workout.date)

                ForEach(unit.orderedSets.filter { session.profile.canSee($0.groupID) }) { workoutSet in
                    CoachSetSection(
                        workoutSet: workoutSet,
                        athletes: session.athletes(for: workoutSet),
                        restTimer: $restTimer
                    ) { repNumber in
                        timingRep = TimingRep(workoutSet: workoutSet, repNumber: repNumber, athletes: session.athletes(for: workoutSet))
                    }
                }
            }
        }
        // Unit notes and start times follow what these groups should see.
        .environment(\.athleteProfile, session.profile)
        .fullScreenCover(item: $timingRep) { rep in
            RepStopwatchView(
                workoutSet: rep.workoutSet,
                repNumber: rep.repNumber,
                athletes: rep.athletes,
                restTimer: $restTimer
            )
        }
    }
}

/// The rep open in the stopwatch, and who's running it.
private struct TimingRep: Identifiable {
    let workoutSet: WorkoutSet
    let repNumber: Int
    let athletes: [Athlete]

    var id: RepKey {
        RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber)
    }
}

// MARK: - Reps

/// A set's reps as rows. Each shows how many athletes have been timed and the rest after it;
/// tapping a rep opens the stopwatch.
private struct CoachSetSection: View {
    let workoutSet: WorkoutSet
    let athletes: [Athlete]
    @Binding var restTimer: RestTimer?
    let onTime: (Int) -> Void

    var body: some View {
        Section {
            ForEach(1...workoutSet.totalReps, id: \.self) { repNumber in
                CoachRepRow(
                    workoutSet: workoutSet,
                    repNumber: repNumber,
                    athletes: athletes,
                    restTimer: $restTimer
                ) {
                    onTime(repNumber)
                }
            }
        } header: {
            Text(workoutSet.summary)
        } footer: {
            if !workoutSet.notes.isEmpty {
                Text(workoutSet.notes)
            }
        }
    }
}

private struct CoachRepRow: View {
    let workoutSet: WorkoutSet
    let repNumber: Int
    let athletes: [Athlete]
    @Binding var restTimer: RestTimer?
    let onTime: () -> Void

    private var timedCount: Int {
        athletes.count { workoutSet.result(forRep: repNumber, athleteID: $0.athleteID) != nil }
    }

    private var restSeconds: Int {
        workoutSet.restSeconds(afterRep: repNumber)
    }

    var body: some View {
        let timed = timedCount
        let isDone = !athletes.isEmpty && timed == athletes.count

        HStack(spacing: 12) {
            Button(action: onTime) {
                HStack(spacing: 12) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "stopwatch")
                        .font(.title2)
                        .foregroundStyle(isDone ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rep \(repNumber) · \(workoutSet.repName)")
                            .fontWeight(.medium)
                        Text(status(timed: timed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(timed == 0 ? "Opens the stopwatch" : "Shows times, or retime the rep")

            if restSeconds > 0 {
                RestTimerButton(
                    key: RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber),
                    seconds: restSeconds,
                    restTimer: $restTimer
                )
            }
        }
    }

    /// e.g. "Set 2 · 3 of 5 timed"
    private func status(timed: Int) -> String {
        let progress = athletes.isEmpty ? "No athletes" : timed == 0 ? "Tap to time" : "\(timed) of \(athletes.count) timed"
        return workoutSet.setCount > 1 ? "Set \(workoutSet.setNumber(forRep: repNumber)) · \(progress)" : progress
    }
}

/// An athlete's name and goal for this rep, and a field for the coach to type their time.
struct CoachTimeRow: View {
    let athlete: Athlete
    let workoutSet: WorkoutSet
    let repNumber: Int
    let focusKey: AthleteRepKey
    let nextFocusKey: AthleteRepKey?
    var focus: FocusState<AthleteRepKey?>.Binding

    @Environment(\.modelContext) private var modelContext
    @State private var text = ""

    /// The athlete's own goal, e.g. the men's or women's time.
    private var target: GroupTarget? {
        athlete.profile.bestMatch(in: workoutSet.targets, groupID: \.groupID)
    }

    private var comparison: GoalComparison? {
        guard let target, let seconds = TimeFormatting.parse(text) else { return nil }
        return target.compare(seconds)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(athlete.name.isEmpty ? "Unnamed Athlete" : athlete.name)
                    .fontWeight(.medium)
                if let target {
                    Text("Goal \(target.goalText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let comparison {
                ComparisonIcon(comparison: comparison)
            }
            TextField(
                "\(athlete.name) time",
                text: $text,
                prompt: Text(target?.goalText ?? "Time")
            )
            .keyboardType(.numbersAndPunctuation)
            .submitLabel(nextFocusKey == nil ? .done : .next)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .focused(focus, equals: focusKey)
            .onSubmit { focus.wrappedValue = nextFocusKey }
            .frame(width: 88)
            .padding(.vertical, 6)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8))
        }
        .onAppear {
            if let result = workoutSet.result(forRep: repNumber, athleteID: athlete.athleteID) {
                text = TimeFormatting.entry(result.seconds)
            }
        }
        .onChange(of: text) { _, newValue in
            workoutSet.logTime(newValue, rep: repNumber, athleteID: athlete.athleteID, byCoach: true, in: modelContext)
        }
    }
}

/// A small marker for how a logged time compares to the goal.
struct ComparisonIcon: View {
    let comparison: GoalComparison

    var body: some View {
        switch comparison {
        case .faster:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Faster than goal")
        case .onTarget:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("On target")
        case .slower:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Slower than goal")
        }
    }
}

#Preview {
    CoachWorkoutView()
        .environment(TrackBoardModel())
        .modelContainer(SampleData.previewContainer)
}
