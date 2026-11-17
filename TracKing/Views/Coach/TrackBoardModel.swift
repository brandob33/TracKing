import SwiftUI
import SwiftData

/// One rep of one set, e.g. rep 2 of "2 × 120m".
struct RepRef: Hashable {
    let set: WorkoutSet
    let repNumber: Int

    static func == (lhs: RepRef, rhs: RepRef) -> Bool {
        lhs.set.persistentModelID == rhs.set.persistentModelID && lhs.repNumber == rhs.repNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(set.persistentModelID)
        hasher.combine(repNumber)
    }

    var key: RepKey {
        RepKey(setID: set.persistentModelID, repNumber: repNumber)
    }

    /// Rest after this rep, in seconds.
    var restSeconds: Int {
        // `self.` keeps Swift from reading a line that starts with `set` as a setter.
        self.set.restSeconds(afterRep: repNumber)
    }
}

/// Finish times captured for a rep that haven't been matched to names yet.
struct CapturedRep: Identifiable {
    let id = UUID()
    let rep: RepRef
    /// Seconds from the start to each finish, fastest first.
    let splits: [TimeInterval]
    /// Who ran it.
    let athletes: [Athlete]
}

/// The live state of one group's card on the Track Board.
struct LaneState {
    enum Position: Equatable {
        /// The first rep that isn't timed yet.
        case auto
        /// A rep the coach moved to, or the one after the rep just run.
        case rep(RepRef)
    }

    var position: Position = .auto
    /// Set while the clock is running.
    var startDate: Date?
    /// Seconds from the start to each finish so far.
    var splits: [TimeInterval] = []
    var rest: RestTimer?
    /// Seconds left on the rest when the coach paused it. `nil` while it's counting down.
    var pausedRestRemaining: TimeInterval?
    /// The rest just ran out: time to send this group.
    var isCalled = false
    /// Reps run but not yet matched to names, oldest first.
    var pending: [CapturedRep] = []
    /// Athlete IDs in the order they were placed on the last named rep.
    var lastOrder: [String] = []

    var isRunning: Bool { startDate != nil }
    var isRestPaused: Bool { pausedRestRemaining != nil }
}

/// How a card is labeled on the lock screen.
struct LaneLabel: Equatable {
    var title: String
    var colorIndex: Int
}

extension GroupSession {
    /// Every timed rep for this group, in order, skipping sets nobody here runs.
    var repSequence: [RepRef] {
        sets
            .filter { !athletes(for: $0).isEmpty }
            .flatMap { workoutSet in
                (1...workoutSet.totalReps).map { RepRef(set: workoutSet, repNumber: $0) }
            }
    }

    /// Whether everyone running this rep has a time for it.
    func isTimed(_ rep: RepRef) -> Bool {
        let runners = athletes(for: rep.set)
        return !runners.isEmpty && runners.allSatisfy { rep.set.result(forRep: rep.repNumber, athleteID: $0.athleteID) != nil }
    }
}

/// Every group's clock, splits, and rest for the practice in progress. It lives above the
/// tabs so clocks keep running wherever the coach is in the app, and it drives the rest
/// alerts and the lock-screen Live Activity.
@Observable
final class TrackBoardModel {
    private(set) var lanes: [String: LaneState] = [:]
    /// Goes up each time a rest runs out, for a haptic buzz.
    private(set) var restEndedCount = 0
    /// Goes up with each finish tap, for a haptic tap.
    private(set) var splitCount = 0

    private var labels: [String: LaneLabel] = [:]
    /// What each resting group runs next, for the lock screen.
    private var nextRepNames: [String: String] = [:]
    /// What each running group is running, for the lock screen.
    private var runningRepNames: [String: String] = [:]
    private var restTasks: [String: Task<Void, Never>] = [:]
    /// The beep with 10 seconds of rest left, one per resting group.
    private var warningTasks: [String: Task<Void, Never>] = [:]
    private let alerts = RestAlerts()
    private let sounds = RestSounds()
    private let volumeButtons = VolumeButtons()
    var workoutTitle = ""

    /// The groups on the timing screen that's showing, so a volume-button press knows who it's for.
    @ObservationIgnored private var visibleSessions: [GroupSession] = []
    /// The group open in Focus, if any.
    @ObservationIgnored private var focusedID: String?
    /// Set once saved timing has been loaded, so an early change can't overwrite it.
    @ObservationIgnored private var hasRestored = false

    func lane(_ id: String) -> LaneState {
        lanes[id] ?? LaneState()
    }

    private func update(_ id: String, _ change: (inout LaneState) -> Void) {
        var lane = lanes[id] ?? LaneState()
        change(&lane)
        lanes[id] = lane
        persist()
    }

    // MARK: Reps

    /// The rep this group runs next, or `nil` when every rep is timed (or waiting on names).
    func currentRep(for session: GroupSession) -> RepRef? {
        let lane = self.lane(session.id)
        if case .rep(let rep) = lane.position, session.repSequence.contains(rep) {
            return rep
        }
        let pending = Set(lane.pending.map(\.rep))
        return session.repSequence.first { !session.isTimed($0) && !pending.contains($0) }
    }

    /// Moves the group to another rep, e.g. to retime one or skip ahead.
    func choose(_ rep: RepRef, for session: GroupSession) {
        update(session.id) { $0.position = .rep(rep) }
    }

    private func position(after rep: RepRef, in session: GroupSession) -> LaneState.Position {
        let sequence = session.repSequence
        if let index = sequence.firstIndex(of: rep), index + 1 < sequence.count {
            return .rep(sequence[index + 1])
        }
        // Past the last rep: go back to anything still untimed.
        return .auto
    }

    // MARK: Timing

    func go(_ session: GroupSession, label: LaneLabel) {
        guard let rep = currentRep(for: session) else { return }
        labels[session.id] = label
        runningRepNames[session.id] = rep.set.repName
        cancelRest(session.id)
        update(session.id) { lane in
            lane.startDate = .now
            lane.splits = []
            lane.rest = nil
            lane.pausedRestRemaining = nil
            lane.isCalled = false
        }
        alerts.requestPermissionIfNeeded()
        refreshLiveActivity()
    }

    /// Records one athlete crossing the line. The rep ends by itself once everyone is in.
    func split(_ session: GroupSession, at date: Date = .now) {
        guard let start = lane(session.id).startDate else { return }
        update(session.id) { $0.splits.append(max(0, date.timeIntervalSince(start))) }
        splitCount += 1
        finishIfEveryoneIsIn(session)
    }

    /// Another athlete finished at the same moment as the last one.
    func tie(_ session: GroupSession) {
        guard let last = lane(session.id).splits.last else { return }
        update(session.id) { $0.splits.append(last) }
        splitCount += 1
        finishIfEveryoneIsIn(session)
    }

    func undoSplit(_ session: GroupSession) {
        update(session.id) { lane in
            if !lane.splits.isEmpty { lane.splits.removeLast() }
        }
    }

    private func finishIfEveryoneIsIn(_ session: GroupSession) {
        guard let rep = currentRep(for: session) else { return }
        if lane(session.id).splits.count >= session.athletes(for: rep.set).count {
            finish(session)
        }
    }

    /// Stops the clock, keeps the times for naming, moves to the next rep, and starts the rest
    /// counted from the last finisher. When only one athlete ran, there's nobody to tell
    /// apart, so their time is saved right away instead of waiting to be named.
    func finish(_ session: GroupSession) {
        let lane = self.lane(session.id)
        guard let start = lane.startDate, let rep = currentRep(for: session) else { return }
        let runners = session.athletes(for: rep.set)
        let next = position(after: rep, in: session)
        let soloRunner = runners.count == 1 ? runners.first : nil
        if let soloRunner, let time = lane.splits.first {
            rep.set.logSeconds(time, rep: rep.repNumber, athleteID: soloRunner.athleteID, byCoach: !session.isPersonal)
        }
        update(session.id) { lane in
            if let soloRunner, !lane.splits.isEmpty {
                lane.lastOrder = [soloRunner.athleteID]
            } else if !lane.splits.isEmpty {
                lane.pending.append(CapturedRep(rep: rep, splits: lane.splits, athletes: runners))
            }
            lane.startDate = nil
            lane.splits = []
            lane.position = next
        }
        let lastFinish = lane.splits.max() ?? Date.now.timeIntervalSince(start)
        startRest(session, after: rep, from: start.addingTimeInterval(lastFinish))
    }

    /// Stops the clock without keeping any times.
    func cancelRep(_ session: GroupSession) {
        update(session.id) { lane in
            lane.startDate = nil
            lane.splits = []
        }
        refreshLiveActivity()
    }

    /// For a rep the coach watches instead of timing: moves on and starts the rest now.
    func restWithoutTiming(_ session: GroupSession, label: LaneLabel) {
        guard let rep = currentRep(for: session) else { return }
        labels[session.id] = label
        let next = position(after: rep, in: session)
        update(session.id) { $0.position = next }
        startRest(session, after: rep, from: .now)
    }

    // MARK: Rest

    private func startRest(_ session: GroupSession, after rep: RepRef, from start: Date) {
        let seconds = rep.restSeconds
        let next = currentRep(for: session)
        guard seconds > 0, let next else {
            update(session.id) { $0.isCalled = next != nil }
            refreshLiveActivity()
            return
        }
        nextRepNames[session.id] = "Next: \(next.set.repName)"
        setRest(RestTimer(rep: rep.key, startDate: start, endDate: start.addingTimeInterval(TimeInterval(seconds))), for: session.id)
    }

    /// Adds time to a running rest.
    func addRest(_ seconds: Int, to session: GroupSession) {
        let lane = self.lane(session.id)
        guard let rest = lane.rest else { return }
        if let paused = lane.pausedRestRemaining {
            // Still paused: just add to what's left.
            update(session.id) { lane in
                lane.pausedRestRemaining = paused + TimeInterval(seconds)
                lane.rest = RestTimer(rep: rest.rep, startDate: rest.startDate, endDate: rest.endDate.addingTimeInterval(TimeInterval(seconds)))
            }
            refreshLiveActivity()
            return
        }
        setRest(RestTimer(rep: rest.rep, startDate: rest.startDate, endDate: rest.endDate.addingTimeInterval(TimeInterval(seconds))), for: session.id)
    }

    /// Ends the rest now and calls the group to the line.
    func skipRest(_ session: GroupSession) {
        cancelRest(session.id)
        update(session.id) { lane in
            lane.rest = nil
            lane.pausedRestRemaining = nil
            lane.isCalled = true
        }
        refreshLiveActivity()
    }

    /// Stops the rest countdown where it is, e.g. while the coach talks to the group.
    /// The end-of-rest alert is held until it's resumed.
    func pauseRest(_ session: GroupSession) {
        let lane = self.lane(session.id)
        guard let rest = lane.rest, !lane.isRestPaused else { return }
        cancelRest(session.id)
        update(session.id) { $0.pausedRestRemaining = max(0, rest.endDate.timeIntervalSinceNow) }
        refreshLiveActivity()
    }

    /// Picks the rest back up with the time that was left.
    func resumeRest(_ session: GroupSession) {
        let lane = self.lane(session.id)
        guard let rest = lane.rest, let remaining = lane.pausedRestRemaining else { return }
        let total = rest.endDate.timeIntervalSince(rest.startDate)
        let now = Date.now
        // Keep the same total so the progress bar picks up where it stopped.
        setRest(RestTimer(rep: rest.rep, startDate: now.addingTimeInterval(remaining - total), endDate: now.addingTimeInterval(remaining)), for: session.id)
    }

    /// Starts the rest over from the full time, counting from now.
    func resetRest(_ session: GroupSession) {
        guard let rest = lane(session.id).rest else { return }
        let total = rest.endDate.timeIntervalSince(rest.startDate)
        let now = Date.now
        setRest(RestTimer(rep: rest.rep, startDate: now, endDate: now.addingTimeInterval(total)), for: session.id)
    }

    /// Starts, replaces, or (with `nil`) stops a group's rest. Used by the plan's rest buttons too.
    func setRest(_ timer: RestTimer?, for id: String) {
        cancelRest(id)
        update(id) { lane in
            lane.rest = timer
            lane.pausedRestRemaining = nil
            lane.isCalled = false
        }
        if let timer {
            alerts.scheduleRestEnd(id: id, title: labels[id]?.title ?? "Rest", at: timer.endDate)
            restTasks[id] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, timer.endDate.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                self?.restEnded(id, timer: timer)
            }
            let untilWarning = timer.endDate.timeIntervalSinceNow - 10
            if untilWarning > 0 {
                warningTasks[id] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(untilWarning))
                    guard !Task.isCancelled, self?.lanes[id]?.rest == timer else { return }
                    self?.sounds.playWarning()
                }
            }
        }
        refreshLiveActivity()
    }

    private func restEnded(_ id: String, timer: RestTimer) {
        guard lanes[id]?.rest == timer else { return }
        update(id) { lane in
            lane.rest = nil
            lane.isCalled = true
        }
        restTasks[id] = nil
        restEndedCount += 1
        sounds.playRestOver()
        refreshLiveActivity()
    }

    private func cancelRest(_ id: String) {
        restTasks[id]?.cancel()
        restTasks[id] = nil
        warningTasks[id]?.cancel()
        warningTasks[id] = nil
        alerts.cancelRestEnd(id: id)
    }

    /// A binding to a group's rest, for screens that start rests themselves.
    func restBinding(for session: GroupSession, label: LaneLabel) -> Binding<RestTimer?> {
        Binding {
            self.lane(session.id).rest
        } set: { timer in
            self.labels[session.id] = label
            if timer != nil, let next = self.currentRep(for: session) {
                self.nextRepNames[session.id] = "Next: \(next.set.repName)"
            }
            self.setRest(timer, for: session.id)
        }
    }

    // MARK: Names

    /// Saves each placed athlete's time. Anyone not placed gets no time for this rep.
    func save(_ captured: CapturedRep, placements: [String?], for sessionID: String) {
        for (index, athleteID) in placements.enumerated() {
            guard let athleteID, captured.splits.indices.contains(index) else { continue }
            captured.rep.set.logSeconds(captured.splits[index], rep: captured.rep.repNumber, athleteID: athleteID, byCoach: true)
        }
        let placed = placements.compactMap(\.self)
        update(sessionID) { lane in
            lane.pending.removeAll { $0.id == captured.id }
            if !placed.isEmpty {
                lane.lastOrder = placed
            }
        }
    }

    /// Throws away times that were captured by mistake.
    func discard(_ captured: CapturedRep, for sessionID: String) {
        update(sessionID) { $0.pending.removeAll { $0.id == captured.id } }
    }

    // MARK: Volume buttons

    /// Tells the board which groups are on screen and starts listening for the volume buttons.
    /// Call it when a timing screen appears.
    func timingScreenAppeared(_ sessions: [GroupSession], eventGroupNames: [String: String]) {
        visibleSessions = sessions
        for session in sessions where labels[session.id] == nil {
            labels[session.id] = session.label(colorIndex: session.colorIndex, eventGroupNames: eventGroupNames)
        }
        volumeButtons.onPress = { [weak self] date in
            self?.volumeButtonPressed(at: date)
        }
        volumeButtons.start()
    }

    /// Stops listening, so the volume buttons change the volume again.
    func timingScreenDisappeared() {
        visibleSessions = []
        focusedID = nil
        volumeButtons.stop()
    }

    /// The group open in Focus, or `nil` back on the board.
    func setFocused(_ id: String?) {
        focusedID = id
    }

    /// Starts or stops listening after the setting is changed.
    func volumeButtonSettingChanged() {
        if TimingSettings.volumeButtons {
            if !visibleSessions.isEmpty { volumeButtons.start() }
        } else {
            volumeButtons.stop()
        }
    }

    /// A press of either volume button.
    ///
    /// In Focus it works the big button for that group: Finish while they're running, GO
    /// when they're ready. On the board it's Finish when exactly one group is running, since
    /// with two running there's no telling which one the press is for.
    private func volumeButtonPressed(at date: Date) {
        if let focusedID, let session = visibleSessions.first(where: { $0.id == focusedID }) {
            let lane = self.lane(focusedID)
            if lane.isRunning {
                split(session, at: date)
            } else if lane.rest == nil, let label = labels[focusedID] {
                go(session, label: label)
            }
            return
        }
        let running = visibleSessions.filter { lane($0.id).isRunning }
        if running.count == 1 {
            split(running[0], at: date)
        }
    }

    // MARK: Saved state

    private static let snapshotKey = "trackBoard.snapshot"

    /// Saves every clock, rest, and time waiting for a name, so nothing is lost if the app
    /// is closed in the middle of practice.
    private func persist() {
        guard hasRestored else { return }
        let worthKeeping = lanes.values.contains { $0.isRunning || $0.rest != nil || !$0.pending.isEmpty }
        guard worthKeeping else {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return
        }
        var saved: [String: BoardSnapshot.Lane] = [:]
        for (id, lane) in lanes {
            var position: BoardSnapshot.Rep?
            if case .rep(let rep) = lane.position {
                position = BoardSnapshot.Rep(setID: rep.set.persistentModelID, repNumber: rep.repNumber)
            }
            saved[id] = BoardSnapshot.Lane(
                position: position,
                startDate: lane.startDate,
                splits: lane.splits,
                restRep: lane.rest.map { BoardSnapshot.Rep(setID: $0.rep.setID, repNumber: $0.rep.repNumber) },
                restStart: lane.rest?.startDate,
                restEnd: lane.rest?.endDate,
                pausedRestRemaining: lane.pausedRestRemaining,
                isCalled: lane.isCalled,
                pending: lane.pending.map { captured in
                    BoardSnapshot.Captured(
                        rep: BoardSnapshot.Rep(setID: captured.rep.set.persistentModelID, repNumber: captured.rep.repNumber),
                        splits: captured.splits,
                        athleteIDs: captured.athletes.map(\.athleteID)
                    )
                },
                lastOrder: lane.lastOrder,
                title: labels[id]?.title ?? "Group",
                colorIndex: labels[id]?.colorIndex ?? 0,
                nextRepName: nextRepNames[id],
                runningRepName: runningRepNames[id]
            )
        }
        let snapshot = BoardSnapshot(savedAt: .now, workoutTitle: workoutTitle, lanes: saved)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    /// Loads timing saved before the app was closed: running clocks keep counting from when
    /// they started, rests pick up where they'd be now, and un-named times come back.
    /// Call it once at launch. Anything older than a day is dropped.
    func restore(sets: [WorkoutSet], athletes: [Athlete]) {
        guard !hasRestored else { return }
        hasRestored = true
        guard
            let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
            let snapshot = try? JSONDecoder().decode(BoardSnapshot.self, from: data),
            Date.now.timeIntervalSince(snapshot.savedAt) < 24 * 60 * 60
        else { return }

        let setsByID = Dictionary(sets.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        func repRef(_ saved: BoardSnapshot.Rep?) -> RepRef? {
            guard let saved, let workoutSet = setsByID[saved.setID] else { return nil }
            return RepRef(set: workoutSet, repNumber: saved.repNumber)
        }

        if workoutTitle.isEmpty {
            workoutTitle = snapshot.workoutTitle
        }
        for (id, saved) in snapshot.lanes {
            var lane = LaneState()
            if let position = repRef(saved.position) {
                lane.position = .rep(position)
            }
            lane.startDate = saved.startDate
            lane.splits = saved.splits
            lane.isCalled = saved.isCalled
            lane.lastOrder = saved.lastOrder
            lane.pending = saved.pending.compactMap { captured in
                guard let rep = repRef(captured.rep) else { return nil }
                let runners = captured.athleteIDs.compactMap { athleteID in athletes.first { $0.athleteID == athleteID } }
                return CapturedRep(rep: rep, splits: captured.splits, athletes: runners)
            }
            labels[id] = LaneLabel(title: saved.title, colorIndex: saved.colorIndex)
            nextRepNames[id] = saved.nextRepName
            runningRepNames[id] = saved.runningRepName
            lanes[id] = lane

            guard let restRep = saved.restRep, let restStart = saved.restStart, let restEnd = saved.restEnd else { continue }
            let timer = RestTimer(rep: RepKey(setID: restRep.setID, repNumber: restRep.repNumber), startDate: restStart, endDate: restEnd)
            if let paused = saved.pausedRestRemaining {
                lanes[id]?.rest = timer
                lanes[id]?.pausedRestRemaining = paused
            } else if restEnd > .now {
                setRest(timer, for: id)
            } else {
                // The rest ran out while the app was closed.
                lanes[id]?.isCalled = true
            }
        }
        refreshLiveActivity()
    }

    // MARK: Lock screen

    private func refreshLiveActivity() {
        let statuses: [TrackBoardActivityAttributes.LaneStatus] = lanes.compactMap { id, lane in
            let label = labels[id] ?? LaneLabel(title: "Group", colorIndex: 0)
            if let start = lane.startDate {
                return .init(id: id, name: label.title, detail: runningRepNames[id] ?? "", colorIndex: label.colorIndex,
                             isRunning: true, startDate: start, endDate: start)
            }
            if let rest = lane.rest {
                return .init(id: id, name: label.title, detail: lane.isRestPaused ? "Rest paused" : nextRepNames[id] ?? "Resting",
                             colorIndex: label.colorIndex, isRunning: false, startDate: rest.startDate, endDate: rest.endDate,
                             pausedRemaining: lane.pausedRestRemaining)
            }
            return nil
        }
        alerts.updateLiveActivity(statuses, workoutTitle: workoutTitle)
    }
}

/// What's written to disk so timing survives the app being closed. Reps are saved by their
/// set's ID and rep number, and athletes by ID, then matched back up at launch.
nonisolated private struct BoardSnapshot: Codable {
    nonisolated struct Rep: Codable {
        var setID: PersistentIdentifier
        var repNumber: Int
    }

    nonisolated struct Captured: Codable {
        var rep: Rep
        var splits: [TimeInterval]
        var athleteIDs: [String]
    }

    nonisolated struct Lane: Codable {
        var position: Rep?
        var startDate: Date?
        var splits: [TimeInterval]
        var restRep: Rep?
        var restStart: Date?
        var restEnd: Date?
        var pausedRestRemaining: TimeInterval?
        var isCalled: Bool
        var pending: [Captured]
        var lastOrder: [String]
        var title: String
        var colorIndex: Int
        var nextRepName: String?
        var runningRepName: String?
    }

    var savedAt: Date
    var workoutTitle: String
    var lanes: [String: Lane]
}
