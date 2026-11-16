import SwiftUI
import SwiftData

/// Full breakdown of a single day's session, unit by unit, where the athlete logs a time for each rep.
struct WorkoutDetailView: View {
    let workout: Workout

    @Environment(\.athleteProfile) private var profile
    @FocusState private var focusedRep: RepKey?
    /// The one rest countdown currently running, if any.
    @State private var restTimer: RestTimer?

    var body: some View {
        List {
            Section {
                WorkoutHeader(workout: workout, startTime: workout.startTime(for: profile))
                if !workout.notes.isEmpty {
                    CoachNote(text: workout.notes)
                }
            }

            ForEach(workout.orderedUnits) { unit in
                UnitSections(
                    unit: unit,
                    number: unit.order + 1,
                    day: workout.date,
                    focus: $focusedRep,
                    restTimer: $restTimer
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Session \(workout.sessionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SeriesRoute.self) { route in
            SeriesDetailView(name: route.name)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedRep = nil }
            }
        }
        .restTimerCountdown($restTimer)
    }
}

/// Navigation value for opening a series from the library.
struct SeriesRoute: Hashable {
    let name: String
}

/// Identifies a single rep within a workout.
struct RepKey: Hashable {
    let setID: PersistentIdentifier
    let repNumber: Int
}

/// A running rest countdown, tied to the rep it follows.
struct RestTimer: Hashable {
    let rep: RepKey
    let startDate: Date
    let endDate: Date
}

extension View {
    /// Clears the rest timer when it reaches zero, with a haptic buzz.
    func restTimerCountdown(_ timer: Binding<RestTimer?>) -> some View {
        modifier(RestTimerCountdown(timer: timer))
    }
}

private struct RestTimerCountdown: ViewModifier {
    @Binding var timer: RestTimer?
    @State private var completedCount = 0

    func body(content: Content) -> some View {
        content
            .task(id: timer) {
                // Clear the countdown when it reaches zero, unless it was cancelled or replaced first.
                guard let running = timer else { return }
                try? await Task.sleep(for: .seconds(max(0, running.endDate.timeIntervalSinceNow)))
                guard !Task.isCancelled, timer == running else { return }
                timer = nil
                completedCount += 1
            }
            .sensoryFeedback(.success, trigger: completedCount)
    }
}

/// Starts a rest countdown for a rep, or stops it if it's already running.
struct RestTimerButton: View {
    let key: RepKey
    let seconds: Int
    @Binding var restTimer: RestTimer?

    var body: some View {
        let activeTimer = restTimer?.rep == key ? restTimer : nil

        Button {
            if activeTimer != nil {
                restTimer = nil
            } else {
                let start = Date.now
                restTimer = RestTimer(rep: key, startDate: start, endDate: start.addingTimeInterval(TimeInterval(seconds)))
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: activeTimer == nil ? "timer" : "stop.fill")
                if let activeTimer {
                    Text(timerInterval: activeTimer.startDate...activeTimer.endDate, countsDown: true)
                } else {
                    Text(TimeFormatting.rest(seconds))
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .frame(minWidth: 64)
        }
        .buttonStyle(.bordered)
        .tint(activeTimer == nil ? Theme.blue : Theme.rest)
        .accessibilityLabel(activeTimer == nil ? "Start rest timer" : "Stop rest timer")
    }
}

// MARK: - Header

private struct WorkoutHeader: View {
    let workout: Workout
    let startTime: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(workout.title)
                .font(.title2.bold())

            HStack(spacing: 16) {
                if let startTime {
                    Label {
                        Text(startTime, format: .dateTime.hour().minute())
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                if !workout.location.isEmpty {
                    Label(workout.location, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.subheadline)

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
        .padding(.vertical, 4)
    }
}

/// A capsule for the week's emphasis, e.g. "DELOAD".
struct FocusBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.gold, in: .capsule)
    }
}

// MARK: - Units

/// A unit's own section, followed by a section per visible set.
private struct UnitSections: View {
    let unit: WorkoutUnit
    let number: Int
    let day: Date
    var focus: FocusState<RepKey?>.Binding
    @Binding var restTimer: RestTimer?

    @Environment(\.athleteProfile) private var profile

    private var visibleSets: [WorkoutSet] {
        unit.orderedSets.filter { profile.canSee($0.groupID) }
    }

    var body: some View {
        UnitInfoSection(unit: unit, number: number, day: day)

        ForEach(visibleSets) { workoutSet in
            Section {
                ForEach(1...workoutSet.totalReps, id: \.self) { repNumber in
                    RepTimeRow(
                        workoutSet: workoutSet,
                        repNumber: repNumber,
                        focus: focus,
                        restTimer: $restTimer
                    )
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
}

/// A unit's title, start time, details, series, exercises, and the coach notes visible to
/// the current `athleteProfile`.
struct UnitInfoSection: View {
    let unit: WorkoutUnit
    let number: Int
    let day: Date

    @Environment(\.athleteProfile) private var profile
    @Environment(\.eventGroupNames) private var eventGroupNames

    private var visibleNotes: [GroupNote] {
        unit.groupNotes.filter { profile.canSee($0.groupID) }
    }

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text("\(number). \(unit.title)")
                        .font(.headline)
                } icon: {
                    Image(systemName: unit.kind.systemImage)
                        .foregroundStyle(.tint)
                }
                Spacer()
                if let startTime = profile.bestMatch(in: unit.startTimes, groupID: \.groupID) {
                    Text(startTime.date(on: day), format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !unit.details.isEmpty {
                Text(unit.details)
                    .font(.subheadline)
            }

            ForEach(unit.seriesNames, id: \.self) { name in
                NavigationLink(value: SeriesRoute(name: name)) {
                    Label(name, systemImage: "list.bullet.rectangle")
                }
            }

            ForEach(unit.exercises, id: \.self) { exercise in
                ExerciseRow(exercise: exercise)
            }

            ForEach(visibleNotes, id: \.self) { note in
                CoachNote(
                    title: note.groupID.map { "For \(TrainingGroup.name(for: $0, eventGroupNames: eventGroupNames))" } ?? "Coach's Note",
                    text: note.text
                )
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: UnitExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(exercise.name)
                    .fontWeight(.medium)
                Spacer()
                Text("\(exercise.sets) × \(exercise.reps)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reps

/// A rep row showing the distance, a text field for the athlete's time (their group's goal
/// time is the placeholder), and a rest countdown button when there's rest after the rep.
private struct RepTimeRow: View {
    let workoutSet: WorkoutSet
    let repNumber: Int
    var focus: FocusState<RepKey?>.Binding
    @Binding var restTimer: RestTimer?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.athleteProfile) private var profile
    @State private var text = ""

    private var key: RepKey {
        RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber)
    }

    private var target: GroupTarget? {
        profile.bestMatch(in: workoutSet.targets, groupID: \.groupID)
    }

    private var restSeconds: Int {
        workoutSet.restSeconds(afterRep: repNumber)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutSet.repName)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            TextField(
                "\(workoutSet.repName) rep \(repNumber) time",
                text: $text,
                // With no goal from the coach, logging a time is optional.
                prompt: Text(target?.goalText ?? "Optional")
            )
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .focused(focus, equals: key)
            .frame(width: 88)
            .padding(.vertical, 6)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8))

            if restSeconds > 0 {
                RestTimerButton(key: key, seconds: restSeconds, restTimer: $restTimer)
            }
        }
        .onAppear {
            if let result = workoutSet.result(forRep: repNumber, athleteID: profile.athleteID) {
                text = TimeFormatting.entry(result.seconds)
            }
        }
        .onChange(of: text) { _, newValue in
            workoutSet.logTime(newValue, rep: repNumber, athleteID: profile.athleteID, byCoach: false, in: modelContext)
        }
    }

    /// Set number for multi-set blocks, and the pace per 100m when the coach gave one.
    private var caption: String? {
        let parts = [
            workoutSet.setCount > 1 ? "Set \(workoutSet.setNumber(forRep: repNumber))" : nil,
            target?.pacePer100.map { "\(TimeFormatting.compact($0))/100m pace" },
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// A note from the coach, styled to stand apart from the routine.
struct CoachNote: View {
    var title = "Coach's Note"
    let text: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
            }
        } icon: {
            Image(systemName: "text.bubble.fill")
                .foregroundStyle(.tint)
        }
    }
}

#Preview("Short Sprint") {
    let container = SampleData.previewContainer
    let workout = try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    NavigationStack {
        if let workout {
            WorkoutDetailView(workout: workout)
        }
    }
    .modelContainer(container)
}

#Preview("Long Sprint") {
    let container = SampleData.previewContainer
    let workout = try? container.mainContext.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    NavigationStack {
        if let workout {
            WorkoutDetailView(workout: workout)
        }
    }
    .environment(\.athleteProfile, AthleteProfile(name: "Athlete", groupIDs: [TrainingGroup.longSprint.id, TrainingGroup.women.id]))
    .modelContainer(container)
}
