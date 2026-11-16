import SwiftUI
import SwiftData
import UIKit

/// One group fills the screen with a big Finish pad, for crowded finishes. The other groups
/// sit in a strip across the top, still showing their clocks and rests, with their own GO,
/// so the coach can send the next group without leaving this one.
struct FocusTimingView: View {
    let workout: Workout

    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String
    @State private var naming: NamingTarget?

    init(workout: Workout, initialID: String) {
        self.workout = workout
        _selectedID = State(initialValue: initialID)
    }

    var body: some View {
        let sessions = GroupSession.all(in: workout, groups: groups, athletes: athletes)
        let index = sessions.firstIndex { $0.id == selectedID } ?? 0

        NavigationStack {
            VStack(spacing: 12) {
                if sessions.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { offset, session in
                                if session.id != sessions[index].id {
                                    MiniLane(session: session, colorIndex: offset) {
                                        withAnimation(.snappy) { selectedID = session.id }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollIndicators(.hidden)
                }

                if sessions.indices.contains(index) {
                    FocusLane(session: sessions[index], colorIndex: index) {
                        naming = NamingTarget(sessionID: sessions[index].id, captured: $0)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                } else {
                    ContentUnavailableView("No Groups", systemImage: "person.3")
                }
            }
            .background(Color.screenBackground)
            .navigationTitle(sessions.indices.contains(index) ? sessions[index].title(eventGroupNames: eventGroupNames) : "Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Board", systemImage: "rectangle.grid.1x2") { dismiss() }
                        .labelStyle(.titleAndIcon)
                }
            }
            .sheet(item: $naming) { target in
                NameTimesSheet(captured: target.captured, sessionID: target.sessionID)
            }
        }
        .sensoryFeedback(.success, trigger: board.restEndedCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: board.splitCount)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// The focused group: big clock, splits, and a Finish pad that fills the rest of the screen.
private struct FocusLane: View {
    let session: GroupSession
    let colorIndex: Int
    let onName: (CapturedRep) -> Void

    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        let lane = board.lane(session.id)
        let rep = board.currentRep(for: session)
        let label = session.label(colorIndex: colorIndex, eventGroupNames: eventGroupNames)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LaneBadge(colorIndex: colorIndex, size: 28)
                Text(repTitle(rep))
                    .font(.headline)
                Spacer()
                if let rep {
                    Text("\(lane.splits.count) of \(session.athletes(for: rep.set).count) in")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if rep == nil {
                Spacer()
                Label("All reps timed", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if lane.isRunning {
                RunningClock(startDate: lane.startDate ?? .now)
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SplitList(splits: lane.splits)
                HStack(spacing: 10) {
                    Button { board.undoSplit(session) } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(lane.splits.isEmpty)
                    Button { board.tie(session) } label: {
                        Label("Tie", systemImage: "equal").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(lane.splits.isEmpty)
                    Button { board.finish(session) } label: {
                        Text("End Rep").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .tint(LaneColor.rest)
                }
                .buttonStyle(.bordered)
                .font(.headline)
                TouchDownButton(
                    title: "Finish",
                    subtitle: "Tap as the \(ordinal(lane.splits.count + 1)) athlete crosses",
                    color: .blue,
                    minHeight: 240,
                    titleSize: 48
                ) {
                    board.split(session)
                }
                .frame(maxHeight: .infinity)
            } else {
                if let rest = lane.rest {
                    RestBody(session: session, rest: rest, large: true)
                } else {
                    Text(lane.isCalled ? "On the line" : "Ready")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(lane.isCalled ? AnyShapeStyle(LaneColor.call) : AnyShapeStyle(.primary))
                }
                Spacer(minLength: 0)
                TouchDownButton(
                    title: "GO",
                    subtitle: lane.rest != nil ? "Send them early" : nil,
                    color: .green,
                    minHeight: 200,
                    titleSize: 56
                ) {
                    board.go(session, label: label)
                }
            }

            PendingNames(pending: lane.pending, onName: onName)
        }
    }

    private func repTitle(_ rep: RepRef?) -> String {
        guard let rep, let index = session.repSequence.firstIndex(of: rep) else { return "Done" }
        return "Rep \(index + 1) of \(session.repSequence.count) · \(rep.set.repName)"
    }
}

/// Another group, shrunk to a chip: its clock or rest, and a GO button when it's ready.
private struct MiniLane: View {
    let session: GroupSession
    let colorIndex: Int
    let onSelect: () -> Void

    @Environment(TrackBoardModel.self) private var board
    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        let lane = board.lane(session.id)
        let rep = board.currentRep(for: session)

        VStack(alignment: .leading, spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    LaneBadge(colorIndex: colorIndex, size: 20)
                    Text(session.title(eventGroupNames: eventGroupNames))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Group {
                if rep == nil {
                    Label("Done", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else if let start = lane.startDate {
                    RunningClock(startDate: start)
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                } else if let rest = lane.rest {
                    Text(timerInterval: rest.startDate...rest.endDate, countsDown: true)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(LaneColor.rest)
                } else {
                    TouchDownButton(title: "GO", color: .green, minHeight: 34, titleSize: 17) {
                        board.go(session, label: session.label(colorIndex: colorIndex, eventGroupNames: eventGroupNames))
                    }
                }
            }
            .frame(height: 34)
        }
        .padding(10)
        .frame(width: 150, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 14))
        .overlay {
            if lane.isCalled && !lane.isRunning && rep != nil {
                RoundedRectangle(cornerRadius: 14).strokeBorder(LaneColor.call, lineWidth: 2)
            }
        }
    }
}
