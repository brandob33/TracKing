import SwiftUI
import SwiftData

/// An athlete's own workout for the day, e.g. over the summer or when training alone.
/// **Timing** is a Track Board card for just them: GO, Finish, and rest starts by itself, with
/// each time saved straight to their account. **Plan** is the full workout with every rep's time.
struct AthleteWorkoutView: View {
    let workout: Workout

    @Query private var athletes: [Athlete]
    @Environment(\.athleteProfile) private var profile
    @Environment(TrackBoardModel.self) private var board
    @State private var mode = Mode.timing

    enum Mode: String, CaseIterable {
        case timing = "Timing"
        case plan = "Plan"
    }

    /// The athlete using this device. Timing is only ever for them.
    private var athlete: Athlete? {
        athletes.first { $0.athleteID == profile.athleteID }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 10)

            switch mode {
            case .timing:
                if let athlete {
                    SelfTimingView(session: GroupSession(workout: workout, personalAthlete: athlete))
                } else {
                    ContentUnavailableView("No Profile", systemImage: "person.crop.circle.badge.questionmark")
                        .frame(maxHeight: .infinity)
                }
            case .plan:
                WorkoutDetailView(workout: workout)
            }
        }
        .background(Color.screenBackground)
        .navigationTitle("Session \(workout.sessionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { board.workoutTitle = workout.title }
    }
}

/// The athlete's own Track Board card, followed by every rep with the time they logged.
private struct SelfTimingView: View {
    let session: GroupSession

    @Environment(TrackBoardModel.self) private var board

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.workout.title)
                        .font(.title2.bold())
                    Text(session.workout.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if session.repSequence.isEmpty {
                    ContentUnavailableView(
                        "No Timed Reps",
                        systemImage: "stopwatch",
                        description: Text("Nothing in today's workout needs a time.")
                    )
                } else {
                    // Someone timing themselves has nothing to name, focus on, or split off.
                    LaneCard(session: session, colorIndex: 0, onFocus: {}, onName: { _ in }, onSplitOff: {})

                    Text("Tap GO when you start and Finish when you cross the line. Rest starts by itself, and your time is saved to your account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    YourReps(session: session)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .keepsScreenAwake()
        .onAppear {
            // An athlete timing themselves can use the volume buttons for GO and Finish.
            board.timingScreenAppeared([session], eventGroupNames: [:])
            board.setFocused(session.id)
        }
        .onDisappear { board.timingScreenDisappeared() }
        .sensoryFeedback(.success, trigger: board.restEndedCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.splitCount)
    }
}

/// Every rep in the athlete's workout, with their time and how it compares to the goal.
/// Tapping one makes it the next rep, e.g. to rerun it.
private struct YourReps: View {
    let session: GroupSession

    @Environment(TrackBoardModel.self) private var board

    var body: some View {
        let athleteID = session.personalAthlete?.athleteID ?? ""
        let current = board.currentRep(for: session)
        let isRunning = board.lane(session.id).isRunning

        VStack(alignment: .leading, spacing: 8) {
            Text("Your Reps")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(session.repSequence.enumerated()), id: \.offset) { index, rep in
                    let result = rep.set.result(forRep: rep.repNumber, athleteID: athleteID)
                    let target = session.profile.bestMatch(in: rep.set.targets, groupID: \.groupID)

                    Button {
                        board.choose(rep, for: session)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rep.set.repName)
                                    .fontWeight(.medium)
                                if let target {
                                    Text("Goal \(target.goalText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let result {
                                if let target {
                                    ComparisonIcon(comparison: target.compare(result.seconds))
                                }
                                Text(TimeFormatting.stopwatch(result.seconds))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            } else if rep == current {
                                Text("Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tint)
                            } else {
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                    .accessibilityHint("Makes this your next rep")

                    if index < session.repSequence.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(.background, in: .rect(cornerRadius: 16))

            Text("Tap a rep to run it next. To fix a time, switch to Plan.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = SampleData.previewContainer
    let context = container.mainContext
    let workout = try? context.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    let athlete = Athlete(name: "Jordan", isDeviceUser: true)
    context.insert(athlete)
    return NavigationStack {
        if let workout {
            AthleteWorkoutView(workout: workout)
        }
    }
    .environment(\.athleteProfile, athlete.profile)
    .environment(TrackBoardModel())
    .modelContainer(container)
}

