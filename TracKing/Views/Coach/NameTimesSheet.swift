import SwiftUI

/// Matches captured finish times to athletes, usually while they rest. Tapping a name puts it
/// on the fastest time that doesn't have one yet; tapping a placed name takes it back off.
struct NameTimesSheet: View {
    let captured: CapturedRep
    let sessionID: String

    @Environment(TrackBoardModel.self) private var board
    @Environment(\.dismiss) private var dismiss
    /// The athlete on each time (by `athleteID`), parallel to `captured.splits`.
    @State private var placements: [String?]
    @State private var isConfirmingDiscard = false

    init(captured: CapturedRep, sessionID: String) {
        self.captured = captured
        self.sessionID = sessionID
        _placements = State(initialValue: Array(repeating: nil, count: captured.splits.count))
    }

    private var unplaced: [Athlete] {
        captured.athletes.filter { !placements.contains($0.athleteID) }
    }

    private var nextOpenSlot: Int? {
        placements.firstIndex { $0 == nil }
    }

    /// The last named rep's order, limited to who ran this one.
    private var lastOrder: [String] {
        let runners = Set(captured.athletes.map(\.athleteID))
        return board.lane(sessionID).lastOrder.filter { runners.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let rest = board.lane(sessionID).rest {
                        HStack {
                            Label("Rest", systemImage: "timer")
                                .font(.headline)
                            Spacer()
                            Text(timerInterval: rest.startDate...rest.endDate, countsDown: true)
                                .font(.title2.bold())
                                .monospacedDigit()
                        }
                        .padding()
                        .background(LaneColor.rest.opacity(0.15), in: .rect(cornerRadius: 16))
                    }

                    Text("Tap names in the order they finished. Tap a name on a time to take it off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(captured.splits.indices, id: \.self) { index in
                        let athlete = placements[index].flatMap { id in captured.athletes.first { $0.athleteID == id } }
                        NamedTimeRow(
                            place: index + 1,
                            seconds: captured.splits[index],
                            athlete: athlete,
                            target: athlete.flatMap { $0.profile.bestMatch(in: captured.rep.set.targets, groupID: \.groupID) },
                            isNext: index == nextOpenSlot
                        ) {
                            placements[index] = nil
                        }
                    }
                }
                .padding()
            }
            .background(Color.screenBackground)
            .safeAreaInset(edge: .bottom) {
                nameTray
            }
            .navigationTitle("Rep \(captured.rep.repNumber) · \(captured.rep.set.repName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        board.save(captured, placements: placements, for: sessionID)
                        dismiss()
                    }
                    .disabled(placements.allSatisfy { $0 == nil })
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Discard Times", role: .destructive) { isConfirmingDiscard = true }
                }
            }
            .confirmationDialog("Discard these times?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard Times", role: .destructive) {
                    board.discard(captured, for: sessionID)
                    dismiss()
                }
            } message: {
                Text("Use this if the rep was a false start or timed by mistake.")
            }
            .sensoryFeedback(.selection, trigger: placements)
        }
    }

    private var nameTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(unplaced.isEmpty ? "Everyone's placed" : "Not placed · \(unplaced.count)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !lastOrder.isEmpty && placements.allSatisfy({ $0 == nil }) {
                    Button("Same Order as Last Rep", systemImage: "arrow.clockwise") {
                        for (index, id) in lastOrder.prefix(placements.count).enumerated() {
                            placements[index] = id
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            if unplaced.isEmpty {
                Text("Tap Save to record the times.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(unplaced) { athlete in
                        Button {
                            if let slot = nextOpenSlot {
                                placements[slot] = athlete.athleteID
                            }
                        } label: {
                            Text(athlete.name.isEmpty ? "Unnamed" : athlete.name)
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.tint)
                                .background(.tint.opacity(0.15), in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .disabled(nextOpenSlot == nil)
                    }
                }
                Text("Anyone not placed gets no time for this rep.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

/// One finish time and the athlete on it, or the spot the next tapped name will fill.
private struct NamedTimeRow: View {
    let place: Int
    let seconds: TimeInterval
    let athlete: Athlete?
    let target: GroupTarget?
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
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Spacer()
            if let athlete {
                if let target {
                    ComparisonIcon(comparison: target.compare(seconds))
                }
                Button(action: onUnplace) {
                    Text(athlete.name.isEmpty ? "Unnamed" : athlete.name)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(minWidth: 90)
                        .foregroundStyle(.white)
                        .background(.tint, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Takes this name off the time")
            } else {
                Text(isNext ? "Next" : "Open")
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
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.tint, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Place \(place), \(TimeFormatting.stopwatch(seconds)), \(athlete?.name ?? "open")")
    }
}
