import SwiftUI
import SwiftData

/// The coach's Results tab: every athlete's time for every rep of a session, group by group,
/// colored against each athlete's goal. Tap a time to fix it, or share the whole session.
///
/// Times are stored once per athlete and rep, so anything saved or fixed here is what that
/// athlete sees on their own Today and History screens.
struct CoachResultsView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @Environment(\.eventGroupNames) private var eventGroupNames

    @State private var date = Calendar.current.startOfDay(for: .now)
    @State private var editing: ResultCell?

    private let calendar = Calendar.current

    private var workout: Workout? {
        workouts.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var workoutDays: Set<Date> {
        Set(workouts.map { calendar.startOfDay(for: $0.date) })
    }

    var body: some View {
        let sessions = workout.map { GroupSession.all(in: $0, groups: groups, athletes: athletes) } ?? []
        let timedSessions = sessions.filter { !$0.repSequence.isEmpty }

        NavigationStack {
            VStack(spacing: 0) {
                DayHeader(date: $date, workout: workout, workoutDays: workoutDays)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if workout == nil {
                    ContentUnavailableView(
                        "No Session",
                        systemImage: "calendar.badge.minus",
                        description: Text("Nothing is scheduled for this day.")
                    )
                    .frame(maxHeight: .infinity)
                } else if timedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Timed Reps",
                        systemImage: "stopwatch",
                        description: Text("Nothing in this session needs a time.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ResultsLegend()
                            ForEach(timedSessions) { session in
                                GroupResultsCard(session: session) { cell in
                                    editing = cell
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.screenBackground)
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let workout, !timedSessions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareText(for: workout, sessions: timedSessions)) {
                            Label("Share Results", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(item: $editing) { cell in
                RepTimesSheet(workoutSet: cell.workoutSet, repNumber: cell.repNumber, athletes: cell.athletes)
            }
        }
    }

    /// The session's results as plain text, ready to paste into a message to the team.
    private func shareText(for workout: Workout, sessions: [GroupSession]) -> String {
        var lines = ["\(workout.title) · \(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"]
        for session in sessions {
            lines.append("")
            lines.append(session.title(eventGroupNames: eventGroupNames))
            for workoutSet in session.sets {
                let runners = session.athletes(for: workoutSet)
                guard !runners.isEmpty else { continue }
                var heading = workoutSet.summary
                if let goal = session.goalText(for: workoutSet) {
                    heading += " · \(goal)"
                }
                lines.append(heading)
                for athlete in runners {
                    let times = (1...workoutSet.totalReps).map { repNumber in
                        workoutSet.result(forRep: repNumber, athleteID: athlete.athleteID).map { TimeFormatting.entry($0.seconds) } ?? "—"
                    }
                    lines.append("\(athlete.name.isEmpty ? "Unnamed" : athlete.name): \(times.joined(separator: ", "))")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// One rep in the grid, and who ran it, for the sheet that fixes times.
struct ResultCell: Identifiable {
    let workoutSet: WorkoutSet
    let repNumber: Int
    let athletes: [Athlete]

    var id: RepKey {
        RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber)
    }
}

/// What the three colors mean.
private struct ResultsLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            item("Faster", Theme.blue)
            item("On goal", Theme.go)
            item("Slower", Theme.rest)
            Spacer()
            Text("Tap a time to fix it")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func item(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

/// One group's results: a grid for each set the group ran.
private struct GroupResultsCard: View {
    let session: GroupSession
    let onEdit: (ResultCell) -> Void

    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                LaneBadge(colorIndex: session.colorIndex, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title(eventGroupNames: eventGroupNames))
                        .font(.headline)
                    Text("\(session.loggedRepCount) of \(session.expectedRepCount) times in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(session.sets) { workoutSet in
                let runners = session.athletes(for: workoutSet)
                if !runners.isEmpty {
                    SetResultsGrid(
                        workoutSet: workoutSet,
                        athletes: runners,
                        goalText: session.goalText(for: workoutSet)
                    ) { repNumber in
                        onEdit(ResultCell(workoutSet: workoutSet, repNumber: repNumber, athletes: runners))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 20))
    }
}

/// Athletes down the side, reps across the top, and each athlete's average at the end.
/// The names stay put while the reps scroll sideways.
private struct SetResultsGrid: View {
    let workoutSet: WorkoutSet
    let athletes: [Athlete]
    let goalText: String?
    let onEdit: (Int) -> Void

    private let headerHeight: CGFloat = 22
    private let rowHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(workoutSet.summary)
                    .font(.subheadline.weight(.semibold))
                if let goalText {
                    Text(goalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: headerHeight)
                    ForEach(athletes) { athlete in
                        Text(athlete.name.isEmpty ? "Unnamed" : athlete.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .frame(height: rowHeight)
                    }
                }
                .frame(width: 88, alignment: .leading)

                ScrollView(.horizontal) {
                    Grid(horizontalSpacing: 6, verticalSpacing: 0) {
                        GridRow {
                            ForEach(1...workoutSet.totalReps, id: \.self) { repNumber in
                                Text("\(repNumber)")
                                    .frame(height: headerHeight)
                            }
                            Text("Avg")
                                .frame(height: headerHeight)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        ForEach(athletes) { athlete in
                            GridRow {
                                ForEach(1...workoutSet.totalReps, id: \.self) { repNumber in
                                    timeCell(for: athlete, repNumber: repNumber)
                                }
                                Text(average(for: athlete))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .frame(minWidth: 50, minHeight: rowHeight)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func timeCell(for athlete: Athlete, repNumber: Int) -> some View {
        let result = workoutSet.result(forRep: repNumber, athleteID: athlete.athleteID)
        let target = athlete.profile.bestMatch(in: workoutSet.targets, groupID: \.groupID)
        let color: Color = {
            guard let result else { return Color.secondary }
            return target.map { $0.compare(result.seconds).color } ?? Color.primary
        }()

        return Button {
            onEdit(repNumber)
        } label: {
            Text(result.map { TimeFormatting.entry($0.seconds) } ?? "—")
                .font(.subheadline.weight(result == nil ? .regular : .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(minWidth: 50, minHeight: rowHeight - 6)
                .background(color.opacity(result == nil ? 0.06 : 0.14), in: .rect(cornerRadius: 8))
                .frame(height: rowHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(athlete.name), rep \(repNumber), \(result.map { TimeFormatting.entry($0.seconds) } ?? "no time")")
        .accessibilityHint("Fixes this rep's times")
    }

    private func average(for athlete: Athlete) -> String {
        let times = workoutSet.results(forAthlete: athlete.athleteID).map(\.seconds)
        guard !times.isEmpty else { return "—" }
        return TimeFormatting.entry(times.reduce(0, +) / Double(times.count))
    }
}

#Preview {
    CoachResultsView()
        .modelContainer(SampleData.previewContainer)
}
