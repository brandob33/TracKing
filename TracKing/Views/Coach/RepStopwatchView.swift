import SwiftUI
import SwiftData
import UIKit

/// Full-screen stopwatch for one rep. Everyone starts together: the coach taps Start, taps
/// Split as each athlete finishes (Tie repeats the last time for simultaneous finishes),
/// then taps Finish, which starts the rest. While athletes rest, the coach places each name
/// on a time and saves.
struct RepStopwatchView: View {
    let workoutSet: WorkoutSet
    let repNumber: Int
    let athletes: [Athlete]
    @Binding var restTimer: RestTimer?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase
    @State private var startDate: Date?
    /// Seconds from the start to each finish, in the order they were captured.
    @State private var splits: [TimeInterval] = []
    @State private var splitTapCount = 0
    /// The athlete placed on each split (by `athleteID`), parallel to `splits`. `nil` is an open time.
    @State private var placements: [String?] = []
    @State private var isConfirmingDiscard = false
    @FocusState private var focusedField: AthleteRepKey?

    enum Phase {
        /// The rep already has times: show them, with the option to retime.
        case review
        case ready
        case running
        case assign
    }

    init(workoutSet: WorkoutSet, repNumber: Int, athletes: [Athlete], restTimer: Binding<RestTimer?>) {
        self.workoutSet = workoutSet
        self.repNumber = repNumber
        self.athletes = athletes
        _restTimer = restTimer
        let hasTimes = athletes.contains { workoutSet.result(forRep: repNumber, athleteID: $0.athleteID) != nil }
        _phase = State(initialValue: hasTimes ? .review : .ready)
    }

    private var title: String {
        "Rep \(repNumber) · \(workoutSet.repName)"
    }

    /// Whether leaving now would throw away captured times.
    private var hasUnsavedTimes: Bool {
        (phase == .running || phase == .assign) && !splits.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .review: reviewView
                case .ready: readyView
                case .running: runningView
                case .assign: assignView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog("Discard these times?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard Times", role: .destructive) { dismiss() }
                Button("Keep Timing", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(hasUnsavedTimes)
        .sensoryFeedback(.impact(weight: .heavy), trigger: splitTapCount)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(phase == .review ? "Done" : "Cancel") {
                if hasUnsavedTimes {
                    isConfirmingDiscard = true
                } else {
                    dismiss()
                }
            }
        }
        switch phase {
        case .running:
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") { finish() }
                    .disabled(splits.isEmpty)
            }
        case .assign:
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        case .review:
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        case .ready:
            ToolbarItem(placement: .confirmationAction) { EmptyView() }
        }
    }

    // MARK: Ready

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(workoutSet.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(TimeFormatting.stopwatch(0))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
            Label(athletes.count == 1 ? "1 athlete" : "\(athletes.count) athletes", systemImage: "person.2.fill")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                start()
            } label: {
                Text("Start")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.goFill)
            .buttonBorderShape(.roundedRectangle(radius: 28))
            .disabled(athletes.isEmpty)
        }
        .padding()
    }

    // MARK: Running

    private var runningView: some View {
        VStack(spacing: 16) {
            if let startDate {
                TimelineView(.animation(minimumInterval: 0.01)) { context in
                    Text(TimeFormatting.stopwatch(context.date.timeIntervalSince(startDate)))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .accessibilityLabel("Running")
            }

            Text("\(splits.count) of \(athletes.count) finished")
                .font(.headline)
                .foregroundStyle(splits.count >= athletes.count ? AnyShapeStyle(Theme.go) : AnyShapeStyle(.secondary))

            // Latest finishes first, so the coach can glance at the last few.
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(splits.enumerated()).reversed(), id: \.offset) { index, split in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(TimeFormatting.stopwatch(split))
                                .fontWeight(.semibold)
                        }
                        .monospacedDigit()
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 120)

            HStack(spacing: 12) {
                Button {
                    splits.removeLast()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .disabled(splits.isEmpty)

                Button {
                    tie()
                } label: {
                    Label("Tie", systemImage: "equal")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .disabled(splits.isEmpty)
            }
            .font(.headline)
            .buttonStyle(.bordered)

            SplitPad(action: split)
        }
        .padding()
    }

    // MARK: Assign

    private var unplacedAthletes: [Athlete] {
        athletes.filter { athlete in !placements.contains(athlete.athleteID) }
    }

    /// Where a tapped name goes: the fastest time nobody has yet.
    private var nextOpenSlot: Int? {
        placements.firstIndex { $0 == nil }
    }

    private var assignView: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let restTimer {
                    RestStatus(timer: restTimer)
                }

                Text("Tap names in finish order, or drag a name onto a time. Tap a placed name to send it back.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(splits.indices, id: \.self) { index in
                    let athlete = placements[index].flatMap { id in athletes.first { $0.athleteID == id } }
                    TimeSlot(
                        place: index + 1,
                        seconds: splits[index],
                        athlete: athlete,
                        target: athlete.flatMap { $0.profile.bestMatch(in: workoutSet.targets, groupID: \.groupID) },
                        isNext: index == nextOpenSlot
                    ) {
                        placements[index] = nil
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let id = ids.first else { return false }
                        place(id, at: index)
                        return true
                    }
                    .contextMenu {
                        Button("Remove Time", systemImage: "trash", role: .destructive) {
                            splits.remove(at: index)
                            placements.remove(at: index)
                        }
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            AthleteTray(athletes: unplacedAthletes) { athlete in
                if let slot = nextOpenSlot {
                    place(athlete.athleteID, at: slot)
                }
            } onDropBack: { id in
                // Dragging a placed name back to the tray takes it off its time.
                if let slot = placements.firstIndex(of: id) {
                    placements[slot] = nil
                }
            }
        }
        .sensoryFeedback(.selection, trigger: placements)
    }

    /// Puts an athlete on a time. If they were already on another time, whoever was here swaps over to it.
    private func place(_ athleteID: String, at slot: Int) {
        let previousSlot = placements.firstIndex(of: athleteID)
        let displaced = placements[slot]
        placements[slot] = athleteID
        if let previousSlot, previousSlot != slot {
            placements[previousSlot] = displaced
        }
    }

    // MARK: Review

    private var reviewView: some View {
        List {
            Section {
                ForEach(Array(athletes.enumerated()), id: \.element.id) { index, athlete in
                    CoachTimeRow(
                        athlete: athlete,
                        workoutSet: workoutSet,
                        repNumber: repNumber,
                        focusKey: key(for: athlete),
                        nextFocusKey: athletes.indices.contains(index + 1) ? key(for: athletes[index + 1]) : nil,
                        focus: $focusedField
                    )
                }
            } header: {
                Text(workoutSet.summary)
            } footer: {
                Text("Type over a time to fix it, or clear it to remove it.")
            }

            Section {
                Button("Retime Rep", systemImage: "stopwatch") {
                    splits = []
                    startDate = nil
                    phase = .ready
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func key(for athlete: Athlete) -> AthleteRepKey {
        AthleteRepKey(rep: RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber), athleteID: athlete.athleteID)
    }

    // MARK: Actions

    private func start() {
        splits = []
        startDate = .now
        phase = .running
    }

    private func split() {
        guard let startDate else { return }
        splits.append(Date.now.timeIntervalSince(startDate))
        splitTapCount += 1
    }

    /// Another athlete finished at the same moment as the last one.
    private func tie() {
        guard let last = splits.last else { return }
        splits.append(last)
        splitTapCount += 1
    }

    /// Stops timing and starts the rest right away, counted from the last finish, so the
    /// coach can place names while the athletes recover.
    private func finish() {
        placements = Array(repeating: nil, count: splits.count)
        // Only one runner: their name goes on the first time, so the coach just taps Save.
        if athletes.count == 1, !placements.isEmpty {
            placements[0] = athletes[0].athleteID
        }
        phase = .assign

        let rest = workoutSet.restSeconds(afterRep: repNumber)
        if rest > 0, let startDate, let lastFinish = splits.max() {
            let restStart = startDate.addingTimeInterval(lastFinish)
            restTimer = RestTimer(
                rep: RepKey(setID: workoutSet.persistentModelID, repNumber: repNumber),
                startDate: restStart,
                endDate: restStart.addingTimeInterval(TimeInterval(rest))
            )
        }
    }

    /// Saves each placed athlete's time. Anyone left unplaced didn't run and gets no time.
    private func save() {
        for athlete in athletes {
            if let slot = placements.firstIndex(of: athlete.athleteID) {
                workoutSet.logSeconds(splits[slot], rep: repNumber, athleteID: athlete.athleteID, byCoach: true)
            } else {
                workoutSet.clearResult(rep: repNumber, athleteID: athlete.athleteID, in: modelContext)
            }
        }
        dismiss()
    }
}

/// A large area that records a split the moment it's touched (not on release), so taps
/// are timed as accurately as possible.
private struct SplitPad: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(isPressed ? Theme.finishFill.opacity(0.7) : Theme.finishFill)
            .overlay {
                Text("Split")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
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
            .accessibilityLabel("Split")
            .accessibilityHint("Records a finish time")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

/// One captured finish time, and the athlete placed on it (or an open spot to drop a name).
private struct TimeSlot: View {
    let place: Int
    let seconds: TimeInterval
    let athlete: Athlete?
    let target: GroupTarget?
    /// Whether a tapped name will land here next.
    let isNext: Bool
    let onUnplace: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(place)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(TimeFormatting.stopwatch(seconds))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Spacer()

            if let athlete {
                if let target {
                    ComparisonIcon(comparison: target.compare(seconds))
                }
                Button(action: onUnplace) {
                    NameChip(name: athlete.name, style: .placed)
                }
                .buttonStyle(.plain)
                .draggable(athlete.athleteID) {
                    NameChip(name: athlete.name, style: .placed)
                }
                .accessibilityHint("Tap to take off this time")
            } else {
                Text(isNext ? "Next" : "Drop name")
                    .font(.subheadline)
                    .foregroundStyle(isNext ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay {
                        Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundStyle(isNext ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    }
            }
        }
        .padding()
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.tint, lineWidth: 2)
            }
        }
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Place \(place), \(TimeFormatting.stopwatch(seconds)), \(athlete?.name ?? "open")")
    }
}

/// The names not yet placed on a time, pinned to the bottom of the screen.
private struct AthleteTray: View {
    let athletes: [Athlete]
    let onTap: (Athlete) -> Void
    let onDropBack: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(athletes.isEmpty ? "Everyone's placed" : "Not placed · \(athletes.count)")
                .font(.subheadline.weight(.semibold))
            if athletes.isEmpty {
                Text("Tap Save to record the times.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(athletes) { athlete in
                        Button {
                            onTap(athlete)
                        } label: {
                            NameChip(name: athlete.name, style: .unplaced)
                        }
                        .buttonStyle(.plain)
                        .draggable(athlete.athleteID) {
                            NameChip(name: athlete.name, style: .unplaced)
                        }
                    }
                }
                Text("Anyone left here didn't run and won't get a time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            onDropBack(id)
            return true
        }
    }
}

/// A capsule with an athlete's name.
private struct NameChip: View {
    enum Style {
        case placed
        case unplaced
    }

    let name: String
    let style: Style

    var body: some View {
        Text(name.isEmpty ? "Unnamed" : name)
            .font(.body.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .foregroundStyle(style == .placed ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
            .background(style == .placed ? AnyShapeStyle(Theme.finishFill) : AnyShapeStyle(.tint.opacity(0.15)), in: .capsule)
    }
}

/// The rest countdown, shown at the top while the coach places names.
private struct RestStatus: View {
    let timer: RestTimer

    var body: some View {
        HStack {
            Label("Rest", systemImage: "timer")
                .font(.headline)
            Spacer()
            Text(timerInterval: timer.startDate...timer.endDate, countsDown: true)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .padding()
        .background(Theme.rest.opacity(0.15), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var restTimer: RestTimer?
    let container = SampleData.previewContainer
    let context = container.mainContext
    let workout = try? context.fetch(
        FetchDescriptor<Workout>(predicate: #Predicate { $0.sessionNumber == 2 }, sortBy: [SortDescriptor(\.date)])
    ).first
    let athletes = ((try? context.fetch(FetchDescriptor<Athlete>(sortBy: [SortDescriptor(\.name)]))) ?? [])
        .filter { $0.eventGroupID == TrainingGroup.shortSprint.id }
    if let workoutSet = workout?.visibleSets(for: .sample).first {
        RepStopwatchView(workoutSet: workoutSet, repNumber: 1, athletes: athletes, restTimer: $restTimer)
            .modelContainer(container)
    }
}

