import SwiftUI
import SwiftData
import UIKit

/// The coach's timing screen: a card for every group practicing today, each with its own
/// clock and one big button that always does the next thing (GO, Finish, then rest by itself).
struct TrackBoardView: View {
    let workout: Workout
    let sessions: [GroupSession]

    @Environment(TrackBoardModel.self) private var board
    @State private var focusedID: FocusTarget?
    @State private var naming: NamingTarget?
    @State private var splittingSession: GroupSession?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "person.3",
                        description: Text("No athletes are running in this session.")
                    )
                }
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    LaneCard(
                        session: session,
                        colorIndex: session.colorIndex,
                        onFocus: { focusedID = FocusTarget(id: session.id) },
                        onName: { naming = NamingTarget(sessionID: session.id, captured: $0) },
                        onSplitOff: { splittingSession = session }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.screenBackground)
        .keepsScreenAwake()
        .fullScreenCover(item: $focusedID) { target in
            FocusTimingView(workout: workout, initialID: target.id)
        }
        .sheet(item: $naming) { target in
            NameTimesSheet(captured: target.captured, sessionID: target.sessionID)
        }
        .sheet(item: $splittingSession) { session in
            SplitOffSheet(session: session)
        }
        .sensoryFeedback(.success, trigger: board.restEndedCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.splitCount)
    }
}

struct FocusTarget: Identifiable {
    let id: String
}

struct NamingTarget: Identifiable {
    let sessionID: String
    let captured: CapturedRep

    var id: UUID { captured.id }
}

extension GroupSession {
    func label(colorIndex: Int, eventGroupNames: [String: String]) -> LaneLabel {
        LaneLabel(title: title(eventGroupNames: eventGroupNames), colorIndex: colorIndex)
    }
}

// MARK: - Card

/// One group on the board. What it shows follows the group's state: ready, running, resting, or done.
struct LaneCard: View {
    let session: GroupSession
    let colorIndex: Int
    let onFocus: () -> Void
    let onName: (CapturedRep) -> Void
    let onSplitOff: () -> Void

    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames

    private var label: LaneLabel {
        session.label(colorIndex: colorIndex, eventGroupNames: eventGroupNames)
    }

    var body: some View {
        let lane = board.lane(session.id)
        let rep = board.currentRep(for: session)

        VStack(alignment: .leading, spacing: 12) {
            LaneHeader(session: session, colorIndex: colorIndex, rep: rep, lane: lane, onFocus: onFocus, onSplitOff: onSplitOff)

            if let rep {
                if lane.isRunning {
                    runningBody(lane: lane, rep: rep)
                } else if let rest = lane.rest {
                    RestBody(session: session, rest: rest)
                } else {
                    readyBody(lane: lane, rep: rep)
                }
            } else {
                Label("All reps timed", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.go)
            }

            PendingNames(pending: lane.pending, onName: onName)
        }
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 20))
        .overlay {
            if lane.isCalled && !lane.isRunning && rep != nil {
                RoundedRectangle(cornerRadius: 20).strokeBorder(LaneColor.call, lineWidth: 3)
            }
        }
        .animation(.snappy, value: lane.isRunning)
        .animation(.snappy, value: lane.rest)
    }

    private func readyBody(lane: LaneState, rep: RepRef) -> some View {
        let runners = session.athletes(for: rep.set).count
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lane.isCalled ? "On the line" : "Ready")
                    .font(.title2.bold())
                    .foregroundStyle(lane.isCalled ? AnyShapeStyle(Theme.goldText) : AnyShapeStyle(.primary))
                Text(session.isPersonal ? "Just you" : runners == 1 ? "1 athlete" : "\(runners) athletes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let goal = session.goalText(for: rep.set) {
                    Text(goal)
                        .font(.subheadline.weight(.semibold))
                }
                if rep.restSeconds > 0 {
                    Button {
                        board.restWithoutTiming(session, label: label)
                    } label: {
                        Label("Rest \(TimeFormatting.rest(rep.restSeconds))", systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(LaneColor.rest)
                    .accessibilityHint("Starts the rest without timing this rep")
                }
            }
            Spacer(minLength: 0)
            TouchDownButton(title: "GO", color: Theme.goFill, minHeight: 76) {
                board.go(session, label: label)
            }
            .frame(width: 130)
        }
    }

    private func runningBody(lane: LaneState, rep: RepRef) -> some View {
        let runners = session.athletes(for: rep.set).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    RunningClock(startDate: lane.startDate ?? .now)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.blue)
                    Text("\(lane.splits.count) of \(runners) in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let goal = session.goalText(for: rep.set) {
                        Text(goal)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                Spacer(minLength: 0)
                TouchDownButton(title: "Finish", subtitle: ordinal(lane.splits.count + 1) + " across", color: Theme.finishFill, minHeight: 92) {
                    board.split(session)
                }
                .frame(width: 130)
            }
            SplitList(splits: lane.splits, goal: session.sharedGoal(for: rep.set))
            HStack(spacing: 8) {
                Button("Undo", systemImage: "arrow.uturn.backward") { board.undoSplit(session) }
                    .disabled(lane.splits.isEmpty)
                Button("Tie", systemImage: "equal") { board.tie(session) }
                    .disabled(lane.splits.isEmpty)
                Spacer()
                Button("End Rep") { board.finish(session) }
                    .tint(LaneColor.rest)
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
        }
    }
}

/// Lane number, group name, the rep up next, status, and the card's menu.
private struct LaneHeader: View {
    let session: GroupSession
    let colorIndex: Int
    let rep: RepRef?
    let lane: LaneState
    let onFocus: () -> Void
    let onSplitOff: () -> Void

    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        HStack(spacing: 10) {
            // Tapping the group's name opens it full screen.
            Button(action: onFocus) {
                HStack(spacing: 10) {
                    LaneBadge(colorIndex: colorIndex)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(session.title(eventGroupNames: eventGroupNames))
                                .font(.headline)
                                .lineLimit(1)
                            if session.dayGroup != nil {
                                Text("Today only")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.tint)
                            }
                            if !session.isPersonal {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(session.isPersonal)
            .accessibilityHint("Opens this group full screen")
            StatusPill(lane: lane, isDone: rep == nil)
            menu
        }
    }

    private var subtitle: String {
        let sequence = session.repSequence
        guard let rep, let index = sequence.firstIndex(of: rep) else {
            return sequence.isEmpty ? "No timed reps" : "\(sequence.count) reps"
        }
        var parts = ["Rep \(index + 1) of \(sequence.count)", rep.set.repName]
        if rep.set.setCount > 1 {
            parts.append("Set \(rep.set.setNumber(forRep: rep.repNumber))")
        }
        return parts.joined(separator: " · ")
    }

    private var menu: some View {
        Menu {
            // Focus switches between the coach's groups, so it doesn't apply to someone timing themselves.
            if !session.isPersonal {
                Button("Focus", systemImage: "arrow.up.left.and.arrow.down.right", action: onFocus)
            }
            let sequence = session.repSequence
            if !sequence.isEmpty && !lane.isRunning {
                Menu("Go to Rep", systemImage: "list.number") {
                    ForEach(Array(sequence.enumerated()), id: \.offset) { index, item in
                        Button {
                            board.choose(item, for: session)
                        } label: {
                            Label(
                                "Rep \(index + 1) · \(item.set.repName)",
                                systemImage: session.isTimed(item) ? "checkmark.circle" : "circle"
                            )
                        }
                    }
                }
            }
            Divider()
            if let dayGroup = session.dayGroup {
                Button("Return to Group", systemImage: "arrow.uturn.backward") {
                    session.workout.returnToGroups(dayGroup.id)
                }
            } else if !session.isPersonal && session.athletes.count > 1 {
                Button("Time Athletes Separately", systemImage: "person.badge.clock", action: onSplitOff)
            }
            if session.dayGroup == nil && session.groupIDs.count > 1 {
                Button("Separate Groups", systemImage: "rectangle.split.2x1") {
                    session.workout.separate(session.groupIDs)
                }
            }
            if lane.rest != nil {
                Divider()
                Button("Restart Rest", systemImage: "arrow.counterclockwise") {
                    board.resetRest(session)
                }
            }
            if lane.isRunning {
                Divider()
                Button("Cancel Rep", systemImage: "xmark", role: .destructive) {
                    board.cancelRep(session)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 36, height: 36)
                .contentShape(.rect)
        }
        .accessibilityLabel("More for \(session.title(eventGroupNames: eventGroupNames))")
    }
}

struct LaneBadge: View {
    let colorIndex: Int
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size / 4)
            .fill(LaneColor.color(colorIndex))
            .frame(width: size, height: size)
            .overlay {
                Text("\(colorIndex + 1)")
                    .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

private struct StatusPill: View {
    let lane: LaneState
    let isDone: Bool

    var body: some View {
        let text: String
        let color: Color
        if isDone {
            text = "Done"
            color = Color.secondary
        } else if lane.isRunning {
            text = "Running"
            color = Theme.blue
        } else if lane.rest != nil {
            text = lane.isRestPaused ? "Paused" : "Rest"
            color = LaneColor.rest
        } else if lane.isCalled {
            text = "Go"
            color = Theme.goldText
        } else {
            text = "Ready"
            color = Theme.go
        }
        return Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: .capsule)
            .foregroundStyle(color)
    }
}

/// The rest countdown with +30s and Skip, and small Pause and Reset buttons.
/// Turns gold in the last 10 seconds.
struct RestBody: View {
    let session: GroupSession
    let rest: RestTimer
    var large = false

    @Environment(TrackBoardModel.self) private var board

    var body: some View {
        let paused = board.lane(session.id).pausedRestRemaining

        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let total = rest.endDate.timeIntervalSince(rest.startDate)
            let left = paused ?? max(0, rest.endDate.timeIntervalSince(context.date))
            let isEnding = paused == nil && left <= 10
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Group {
                            if let paused {
                                // Held still while paused.
                                Text(TimeFormatting.rest(Int(paused.rounded(.up))))
                                    .opacity(0.6)
                            } else {
                                Text(timerInterval: rest.startDate...rest.endDate, countsDown: true)
                            }
                        }
                        .font(.system(size: large ? 72 : 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isEnding ? Theme.goldText : LaneColor.rest)

                        Text(paused == nil ? "Rest of \(TimeFormatting.rest(Int(total.rounded()))) · from last finisher" : "Rest paused")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                ProgressView(value: total > 0 ? min(1, 1 - left / total) : 1)
                    .tint(isEnding ? LaneColor.call : LaneColor.rest)
                RestControls(session: session, isPaused: paused != nil)
            }
        }
    }
}

/// Pause/Resume, +30s, and Skip for a running rest, each a full-size button. Restarting the
/// rest lives in the card's menu, away from these, so it can't be hit by accident.
private struct RestControls: View {
    let session: GroupSession
    let isPaused: Bool

    @Environment(TrackBoardModel.self) private var board

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isPaused {
                    board.resumeRest(session)
                } else {
                    board.pauseRest(session)
                }
            } label: {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .tint(LaneColor.rest)
            Button {
                board.addRest(30, to: session)
            } label: {
                Text("+30s").frame(maxWidth: .infinity, minHeight: 32)
            }
            Button {
                board.skipRest(session)
            } label: {
                Text("Skip").frame(maxWidth: .infinity, minHeight: 32)
            }
        }
        .buttonStyle(.bordered)
        .font(.subheadline.weight(.semibold))
    }
}

/// A stopwatch reading that updates every frame.
struct RunningClock: View {
    let startDate: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            Text(TimeFormatting.stopwatch(max(0, context.date.timeIntervalSince(startDate))))
                .monospacedDigit()
        }
        .accessibilityLabel("Running")
    }
}

/// Finish times so far, fastest first. When everyone running shares one goal, each time is
/// colored against it: blue is faster, green is on target, orange is slower.
struct SplitList: View {
    let splits: [TimeInterval]
    var goal: GroupTarget?

    var body: some View {
        if splits.isEmpty {
            Text("Tap Finish as each athlete crosses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(splits.enumerated()), id: \.offset) { _, seconds in
                        let color = goal.map { $0.compare(seconds).color } ?? Color.primary
                        Text(TimeFormatting.stopwatch(seconds))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .foregroundStyle(color)
                            .background(color.opacity(0.14), in: .capsule)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.trailing)
        }
    }
}

extension GoalComparison {
    /// Blue is faster than the goal, green is on it, orange is slower.
    var color: Color {
        switch self {
        case .faster: Theme.blue
        case .onTarget: Theme.go
        case .slower: Theme.rest
        }
    }
}

extension GroupSession {
    /// The goal for each athlete running a set, without repeats, e.g. the men's and the women's.
    func goals(for workoutSet: WorkoutSet) -> [GroupTarget] {
        var result: [GroupTarget] = []
        for athlete in athletes(for: workoutSet) {
            if let target = athlete.profile.bestMatch(in: workoutSet.targets, groupID: \.groupID), !result.contains(target) {
                result.append(target)
            }
        }
        return result
    }

    /// The goal when everyone running the set has the same one. Finish taps aren't matched
    /// to names yet, so times can only be colored when there's a single goal to compare to.
    func sharedGoal(for workoutSet: WorkoutSet) -> GroupTarget? {
        let all = goals(for: workoutSet)
        return all.count == 1 ? all[0] : nil
    }

    /// "Goal 16.0", or "Goal M 16.0 · W 18.5" when the runners have different goals.
    func goalText(for workoutSet: WorkoutSet) -> String? {
        let all = goals(for: workoutSet)
        guard !all.isEmpty else { return nil }
        if all.count == 1 {
            return "Goal \(all[0].goalText)"
        }
        let parts = all.map { target -> String in
            let who: String
            switch target.groupID {
            case TrainingGroup.men.id: who = "M "
            case TrainingGroup.women.id: who = "W "
            case let id?: who = TrainingGroup.name(for: id) + " "
            case nil: who = ""
            }
            return who + target.goalText
        }
        return "Goal " + parts.joined(separator: " · ")
    }
}

extension View {
    /// Keeps the phone from locking while this screen is showing, so a finish is never
    /// missed because the screen went to sleep.
    func keepsScreenAwake() -> some View {
        onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// Reps waiting for names, each a button that opens the naming sheet.
struct PendingNames: View {
    let pending: [CapturedRep]
    let onName: (CapturedRep) -> Void

    var body: some View {
        if !pending.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(pending) { captured in
                        Button {
                            onName(captured)
                        } label: {
                            Label("Name \(captured.splits.count) times · \(captured.rep.set.repName)", systemImage: "person.text.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .overlay {
                                    Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                }
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// A big button that fires the moment it's touched rather than on release, so finish taps are
/// timed as accurately as possible.
struct TouchDownButton: View {
    let title: String
    var subtitle: String?
    let color: Color
    var minHeight: CGFloat = 76
    var titleSize: CGFloat = 30
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(color.opacity(isPressed ? 0.7 : 1))
            .overlay {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                    }
                    .onEnded { _ in isPressed = false }
            )
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

func ordinal(_ number: Int) -> String {
    let suffix: String
    switch (number % 10, number % 100) {
    case (_, 11...13): suffix = "th"
    case (1, _): suffix = "st"
    case (2, _): suffix = "nd"
    case (3, _): suffix = "rd"
    default: suffix = "th"
    }
    return "\(number)\(suffix)"
}
