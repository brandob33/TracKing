import SwiftUI
import SwiftData

/// The coach's home: today's session, a Start Workout button, and every event group
/// practicing with its start time and timing progress. Starting the workout (or tapping a
/// group) opens the live screen, where the coach jumps between groups while timing.
struct CoachTodayView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]

    @State private var date: Date
    /// One rest countdown per group (keyed by `GroupSession.id`), so groups can rest at the
    /// same time. Kept here so rests keep counting wherever the coach is in the app.
    @State private var restTimers: [String: RestTimer] = [:]
    @State private var isCombining = false

    private let calendar = Calendar.current

    init(initialDate: Date = .now) {
        _date = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var workout: Workout? {
        workouts.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var sessions: [GroupSession] {
        guard let workout else { return [] }
        return GroupSession.all(in: workout, groups: groups, athletes: athletes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DayHeader(date: $date, workout: workout)
                }

                if let workout {
                    let sessions = sessions
                    let hasStarted = sessions.contains { $0.loggedRepCount > 0 }

                    Section {
                        NavigationLink(value: LiveRoute(workout: workout, selectedSessionID: nil)) {
                            Label(hasStarted ? "Resume Workout" : "Start Workout", systemImage: "play.fill")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .listRowBackground(Color.accentColor)
                        .foregroundStyle(.white)
                        .disabled(sessions.isEmpty)
                    }

                    Section {
                        ForEach(sessions) { session in
                            NavigationLink(value: LiveRoute(workout: workout, selectedSessionID: session.id)) {
                                GroupSessionCard(session: session, restTimer: restTimers[session.id])
                            }
                            .contextMenu {
                                if session.groupIDs.count > 1 {
                                    Button("Separate Groups", systemImage: "rectangle.split.2x1") {
                                        workout.separate(session.groupIDs)
                                    }
                                }
                            }
                            .swipeActions {
                                if session.groupIDs.count > 1 {
                                    Button("Separate", systemImage: "rectangle.split.2x1") {
                                        workout.separate(session.groupIDs)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Groups")
                    } footer: {
                        Text("Running two groups together? Tap Combine to time them on one screen for this day. Swipe a combined group to separate it.")
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Session",
                            systemImage: "calendar.badge.minus",
                            description: Text("Nothing is scheduled for this day.")
                        )
                    }
                }
            }
            .navigationTitle("Today")
            .navigationDestination(for: LiveRoute.self) { route in
                LivePracticeView(
                    workout: route.workout,
                    initialSessionID: route.selectedSessionID,
                    restTimers: $restTimers
                )
            }
            .navigationDestination(for: SeriesRoute.self) { route in
                SeriesDetailView(name: route.name)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Combine", systemImage: "rectangle.stack.badge.plus") {
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
            .safeAreaInset(edge: .bottom) {
                RestBanner(timers: $restTimers, names: sessionNames)
            }
            .restTimersCountdown($restTimers)
        }
    }

    /// Group names by session ID, for labeling rests in the banner.
    private var sessionNames: [String: String] {
        Dictionary(sessions.map { ($0.id, $0.title(eventGroupNames: groupNames)) }, uniquingKeysWith: { first, _ in first })
    }

    private var groupNames: [String: String] {
        Dictionary(groups.map { ($0.groupID, $0.name) }, uniquingKeysWith: { first, _ in first })
    }
}

/// Navigation value for the live practice screen, optionally opened on one group.
private struct LiveRoute: Hashable {
    let workout: Workout
    let selectedSessionID: String?
}

extension GroupSession {
    /// e.g. "Short Sprints + Short Hurdles"
    func title(eventGroupNames: [String: String]) -> String {
        groupIDs.map { TrainingGroup.name(for: $0, eventGroupNames: eventGroupNames) }.joined(separator: " + ")
    }
}

/// Identifies one athlete's time field for one rep, for keyboard focus.
struct AthleteRepKey: Hashable {
    let rep: RepKey
    let athleteID: String
}

// MARK: - Today list

/// Day navigation and the session's title and week.
private struct DayHeader: View {
    @Binding var date: Date
    let workout: Workout?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Previous Day", systemImage: "chevron.left") { moveDay(by: -1) }
                Spacer()
                VStack(spacing: 2) {
                    Text(calendar.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(date, format: .dateTime.weekday(.abbreviated).month(.wide).day())
                        .font(.headline)
                }
                Spacer()
                Button("Next Day", systemImage: "chevron.right") { moveDay(by: 1) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)

            if !calendar.isDateInToday(date) {
                Button("Back to Today") {
                    date = calendar.startOfDay(for: .now)
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }

            if let workout {
                VStack(spacing: 4) {
                    Text(workout.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    if let week = workout.week {
                        HStack(spacing: 8) {
                            Text(week.cycleSummary)
                            if !week.focus.isEmpty {
                                FocusBadge(text: week.focus)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func moveDay(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: date) {
            date = newDate
        }
    }
}

/// A practicing group on the Today list: names, start time, athletes, sets, and timing progress.
private struct GroupSessionCard: View {
    let session: GroupSession
    let restTimer: RestTimer?

    @Environment(\.eventGroupNames) private var eventGroupNames

    private var title: String {
        session.title(eventGroupNames: eventGroupNames)
    }

    var body: some View {
        let sets = session.sets
        let expected = session.expectedRepCount
        let logged = session.loggedRepCount

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let startTime = session.startTime {
                    Text(startTime, format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if session.groupIDs.count > 1 {
                Label("Combined", systemImage: "rectangle.stack.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            Text(sets.isEmpty ? "No timed reps" : sets.map(\.repsAndDistance).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(session.athletes.count == 1 ? "1 athlete" : "\(session.athletes.count) athletes", systemImage: "person.2.fill")
                if expected > 0 {
                    Label("\(logged)/\(expected) timed", systemImage: logged >= expected ? "checkmark.circle.fill" : "stopwatch")
                        .foregroundStyle(logged >= expected ? .green : .secondary)
                }
                if let restTimer {
                    Label {
                        Text(timerInterval: restTimer.startDate...restTimer.endDate, countsDown: true)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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

// MARK: - Timing screen

/// One group's (or combination's) session: the same units the athletes see, with every rep
/// listing each athlete running it and a time field, and the shared rest timer.
struct CoachGroupSessionView: View {
    let workout: Workout
    let groupIDs: [String]
    @Binding var restTimer: RestTimer?

    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @Environment(\.eventGroupNames) private var eventGroupNames
    /// The rep open in the stopwatch.
    @State private var timingRep: TimingRep?

    private var session: GroupSession {
        GroupSession(workout: workout, groupIDs: groupIDs, allAthletes: athletes)
    }

    private var title: String {
        groupIDs.map { TrainingGroup.name(for: $0, eventGroupNames: eventGroupNames) }.joined(separator: " + ")
    }

    var body: some View {
        let session = session

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

// MARK: - Rest banner

/// Bars pinned above the tab bar for each group that's resting, so the coach sees every
/// countdown from anywhere in the app.
private struct RestBanner: View {
    @Binding var timers: [String: RestTimer]
    let names: [String: String]

    var body: some View {
        let running = timers.sorted { $0.value.endDate < $1.value.endDate }
        if !running.isEmpty {
            VStack(spacing: 6) {
                ForEach(running, id: \.key) { id, timer in
                    HStack {
                        Label(names[id] ?? "Rest", systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(timerInterval: timer.startDate...timer.endDate, countsDown: true)
                            .font(.title3.bold())
                            .monospacedDigit()
                        Button("Stop", systemImage: "stop.fill") {
                            timers[id] = nil
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(12)
            .background(.orange.opacity(0.15), in: .rect(cornerRadius: 16))
            .background(.background, in: .rect(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

extension View {
    /// Clears each group's rest when it reaches zero, with a haptic buzz.
    func restTimersCountdown(_ timers: Binding<[String: RestTimer]>) -> some View {
        modifier(RestTimersCountdown(timers: timers))
    }
}

private struct RestTimersCountdown: ViewModifier {
    @Binding var timers: [String: RestTimer]
    @State private var completedCount = 0

    func body(content: Content) -> some View {
        content
            .task(id: timers) {
                // Sleep until the next rest ends; any change to the timers restarts this.
                guard let nextEnd = timers.values.map(\.endDate).min() else { return }
                try? await Task.sleep(for: .seconds(max(0, nextEnd.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                let now = Date.now
                let finished = timers.filter { $0.value.endDate <= now }.map(\.key)
                guard !finished.isEmpty else { return }
                for id in finished {
                    timers[id] = nil
                }
                completedCount += 1
            }
            .sensoryFeedback(.success, trigger: completedCount)
    }
}

// MARK: - Live practice

/// The workout in progress: every practicing group in a strip across the top, with the
/// selected group's timing screen below. Swipe or tap a group to jump to it.
struct LivePracticeView: View {
    let workout: Workout
    @Binding var restTimers: [String: RestTimer]

    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @Environment(\.eventGroupNames) private var eventGroupNames
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    @State private var isCombining = false

    init(workout: Workout, initialSessionID: String?, restTimers: Binding<[String: RestTimer]>) {
        self.workout = workout
        _restTimers = restTimers
        _selectedID = State(initialValue: initialSessionID)
    }

    private var sessions: [GroupSession] {
        GroupSession.all(in: workout, groups: groups, athletes: athletes)
    }

    var body: some View {
        let sessions = sessions
        // Falls back to the first group if the selected one was combined or separated.
        let selection = Binding<String?> {
            sessions.contains { $0.id == selectedID } ? selectedID : sessions.first?.id
        } set: {
            selectedID = $0
        }

        VStack(spacing: 0) {
            GroupStrip(sessions: sessions, selection: selection, restTimers: restTimers)

            TabView(selection: selection) {
                ForEach(sessions) { session in
                    CoachGroupSessionView(
                        workout: workout,
                        groupIDs: session.groupIDs,
                        restTimer: restTimerBinding(for: session.id)
                    )
                    .tag(Optional(session.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.screenBackground)
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Combine", systemImage: "rectangle.stack.badge.plus") {
                    isCombining = true
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("End") { dismiss() }
            }
        }
        .sheet(isPresented: $isCombining) {
            CombineGroupsSheet(workout: workout, groups: groups)
        }
    }

    private func restTimerBinding(for id: String) -> Binding<RestTimer?> {
        Binding { restTimers[id] } set: { restTimers[id] = $0 }
    }
}

/// Tappable chips for each practicing group, showing progress and any running rest.
private struct GroupStrip: View {
    let sessions: [GroupSession]
    @Binding var selection: String?
    let restTimers: [String: RestTimer]

    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sessions) { session in
                        let isSelected = session.id == selection
                        Button {
                            withAnimation { selection = session.id }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title(eventGroupNames: eventGroupNames))
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                if let timer = restTimers[session.id] {
                                    Label {
                                        Text(timerInterval: timer.startDate...timer.endDate, countsDown: true)
                                            .monospacedDigit()
                                    } icon: {
                                        Image(systemName: "timer")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.orange))
                                } else if session.expectedRepCount > 0 {
                                    Text("\(session.loggedRepCount)/\(session.expectedRepCount) timed")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .opacity(0.8)
                                } else {
                                    Text("No timed reps")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .id(session.id)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

#Preview("Today") {
    CoachTodayView()
        .modelContainer(SampleData.previewContainer)
}

#Preview("Live, Tuesday") {
    @Previewable @State var restTimers: [String: RestTimer] = [:]
    let container = SampleData.previewContainer
    let workout = try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).dropFirst().first
    NavigationStack {
        if let workout {
            LivePracticeView(workout: workout, initialSessionID: nil, restTimers: $restTimers)
        }
    }
    .modelContainer(container)
}
