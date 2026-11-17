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
    @State private var editing: EditPlanRoute?
    @AppStorage(TimingSettings.restSoundsKey) private var restSounds = true
    @AppStorage(TimingSettings.volumeButtonsKey) private var volumeButtons = true

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

    private var workoutDays: Set<Date> {
        Set(workouts.map { calendar.startOfDay(for: $0.date) })
    }

    var body: some View {
        let sessions = workout.map { GroupSession.all(in: $0, groups: groups, athletes: athletes) } ?? []

        NavigationStack {
            VStack(spacing: 0) {
                DayHeader(date: $date, workout: workout, workoutDays: workoutDays)
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
            .navigationDestination(item: $editing) { route in
                GroupWorkoutEditor(group: route.group, workout: route.workout)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Timing Options", systemImage: "gearshape") {
                        Toggle("Rest Beeps", systemImage: "speaker.wave.2", isOn: $restSounds)
                        Toggle("Volume Buttons Tap Finish", systemImage: "hand.tap", isOn: $volumeButtons)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Combine Groups", systemImage: "rectangle.stack.badge.plus") {
                        isCombining = true
                    }
                    .disabled(workout == nil)
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
        .onChange(of: volumeButtons) { board.volumeButtonSettingChanged() }
    }

    /// Opens the plan editor for the group on screen. Combined groups each have their own
    /// plan, so the coach picks which one to edit.
    @ViewBuilder
    private func editPlanButton(for session: GroupSession) -> some View {
        let editable = groups.filter { session.groupIDs.contains($0.groupID) }
        if editable.count == 1 {
            Button("Edit Plan", systemImage: "pencil") {
                editing = EditPlanRoute(group: editable[0], workout: session.workout)
            }
        } else if editable.count > 1 {
            Menu("Edit Plan", systemImage: "pencil") {
                ForEach(editable) { group in
                    Button(group.name) {
                        editing = EditPlanRoute(group: group, workout: session.workout)
                    }
                }
            }
        }
    }

    /// The full plan for one group, picked from a menu, so warm-ups and notes are a tap away.
    @ViewBuilder
    private func planView(sessions: [GroupSession]) -> some View {
        let index = sessions.firstIndex { $0.id == planSessionID } ?? 0
        if sessions.indices.contains(index) {
            let session = sessions[index]
            VStack(spacing: 0) {
                HStack {
                    Picker("Group", selection: Binding(get: { session.id }, set: { planSessionID = $0 })) {
                        ForEach(sessions) { Text($0.title(eventGroupNames: eventGroupNames)).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                    editPlanButton(for: session)
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal)

                CoachGroupSessionView(
                    session: session,
                    restTimer: board.restBinding(for: session, label: session.label(colorIndex: session.colorIndex, eventGroupNames: eventGroupNames))
                ) { rep in
                    // Put the group on that rep and show the Track Board.
                    board.choose(rep, for: session)
                    mode = .timing
                }
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
        if isPersonal {
            return "Your Workout"
        }
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

/// The session's title and a week of days to pick from. Shared by the Workout and Results tabs.
struct DayHeader: View {
    @Binding var date: Date
    let workout: Workout?
    /// Start-of-day dates that have a session, for the dots under the week.
    let workoutDays: Set<Date>

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                LogoMark(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workout?.title ?? "No Session")
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(calendar.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                            .foregroundStyle(.tint)
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 4)
                if let focus = workout?.week?.focus, !focus.isEmpty {
                    FocusBadge(text: focus)
                }
                if !calendar.isDateInToday(date) {
                    Button("Today") {
                        date = calendar.startOfDay(for: .now)
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
            WeekStrip(selectedDate: $date, workoutDays: workoutDays)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Opens the editor for one group's part of a session.
struct EditPlanRoute: Hashable {
    let group: EventGroup
    let workout: Workout
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

/// One group's whole plan for the day: warm-ups, drills, notes, and every set. Tapping a rep
/// shows its times, to fix one or send the rep back to the Track Board.
struct CoachGroupSessionView: View {
    let session: GroupSession
    @Binding var restTimer: RestTimer?
    /// Called when the coach wants to time a rep again on the Track Board.
    let onRetime: (RepRef) -> Void

    /// The rep whose times are showing.
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
        .sheet(item: $timingRep) { rep in
            RepTimesSheet(workoutSet: rep.workoutSet, repNumber: rep.repNumber, athletes: rep.athletes) {
                onRetime(RepRef(set: rep.workoutSet, repNumber: rep.repNumber))
            }
        }
    }
}

/// One rep's times for everyone who ran it. Type over a time to fix it, clear it to remove
/// it, or send the rep back to the Track Board to time it again.
struct RepTimesSheet: View {
    let workoutSet: WorkoutSet
    let repNumber: Int
    let athletes: [Athlete]
    /// Leave out to hide "Time This Rep Again".
    var onRetime: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: AthleteRepKey?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if athletes.isEmpty {
                        Text("Nobody in this group runs this rep.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(athletes.enumerated()), id: \.offset) { index, athlete in
                        CoachTimeRow(
                            athlete: athlete,
                            workoutSet: workoutSet,
                            repNumber: repNumber,
                            focusKey: key(for: athlete),
                            nextFocusKey: index + 1 < athletes.count ? key(for: athletes[index + 1]) : nil,
                            focus: $focusedField
                        )
                    }
                } header: {
                    Text(workoutSet.summary)
                } footer: {
                    Text("Type over a time to fix it, or clear it to remove it. Changes save as you type.")
                }

                if let onRetime, !athletes.isEmpty {
                    Section {
                        Button("Time This Rep Again", systemImage: "stopwatch") {
                            onRetime()
                            dismiss()
                        }
                    } footer: {
                        Text("Opens the Track Board on this rep. New times replace the ones here.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Rep \(repNumber) · \(workoutSet.repName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func key(for athlete: Athlete) -> AthleteRepKey {
        AthleteRepKey(rep: RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber), athleteID: athlete.athleteID)
    }
}

/// The rep whose times are showing, and who ran it.
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
/// tapping a rep shows its times.
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
                        .foregroundStyle(isDone ? AnyShapeStyle(Theme.go) : AnyShapeStyle(.tint))
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
            .accessibilityHint("Shows this rep's times")

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
        let progress = athletes.isEmpty ? "No athletes" : timed == 0 ? "Not timed" : "\(timed) of \(athletes.count) timed"
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
                .foregroundStyle(Theme.blue)
                .accessibilityLabel("Faster than goal")
        case .onTarget:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.go)
                .accessibilityLabel("On target")
        case .slower:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(Theme.rest)
                .accessibilityLabel("Slower than goal")
        }
    }
}

#Preview {
    CoachWorkoutView()
        .environment(TrackBoardModel())
        .modelContainer(SampleData.previewContainer)
}
