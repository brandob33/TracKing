import Foundation
import SwiftData

/// An event group the coach creates, e.g. "Short Sprints". Athletes are assigned to one,
/// and see only the sets, start times, and notes the coach writes for it.
@Model
final class EventGroup {
    /// Stable ID that sets, notes, start times, and athletes refer to. It never changes, even when the group is renamed.
    @Attribute(.unique) var groupID: String
    var name: String
    /// Position in the coach's list.
    var order: Int

    init(groupID: String = UUID().uuidString, name: String, order: Int) {
        self.groupID = groupID
        self.name = name
        self.order = order
    }

    /// The groups a new team starts with.
    static func defaults() -> [EventGroup] {
        TrainingGroup.defaultEventGroups.enumerated().map { index, group in
            EventGroup(groupID: group.id, name: group.name, order: index)
        }
    }

    /// The sets written for this group in a workout, in order.
    func sets(in workout: Workout) -> [WorkoutSet] {
        workout.orderedUnits.flatMap { unit in
            unit.orderedSets.filter { $0.groupID == groupID }
        }
    }
}

extension EventGroup {
    /// Deletes a group along with everything aimed at it: its sets, start times, and notes.
    /// Athletes in the group become unassigned.
    @MainActor
    static func delete(_ group: EventGroup, in context: ModelContext) {
        let id = group.groupID

        let sets = (try? context.fetch(FetchDescriptor<WorkoutSet>())) ?? []
        for workoutSet in sets where workoutSet.groupID == id {
            context.delete(workoutSet)
        }

        let units = (try? context.fetch(FetchDescriptor<WorkoutUnit>())) ?? []
        for unit in units {
            unit.startTimes.removeAll { $0.groupID == id }
            unit.groupNotes.removeAll { $0.groupID == id }
        }

        let athletes = (try? context.fetch(FetchDescriptor<Athlete>())) ?? []
        for athlete in athletes where athlete.eventGroupID == id {
            athlete.eventGroupID = ""
        }

        context.delete(group)
    }
}

// MARK: - Coach editing helpers

extension Workout {
    /// The unit new running sets and group notes go in: the first running unit, created after the warm-up if there isn't one.
    func runningUnit() -> WorkoutUnit {
        if let unit = orderedUnits.first(where: { $0.kind == .running }) {
            return unit
        }
        let insertAt = (orderedUnits.first { $0.kind == .warmUp }?.order ?? -1) + 1
        for unit in units where unit.order >= insertAt {
            unit.order += 1
        }
        let unit = WorkoutUnit(order: insertAt, kind: .running, title: "Running")
        units.append(unit)
        return unit
    }

    /// A start time aimed at exactly this group, if the coach set one.
    func startTime(forGroup groupID: String) -> GroupStartTime? {
        orderedUnits.lazy.compactMap { $0.startTimes.first { $0.groupID == groupID } }.first
    }

    /// Sets, replaces, or (with `nil`) removes this group's start time. It's stored on the first unit.
    func setStartTime(_ time: GroupStartTime?, forGroup groupID: String) {
        for unit in units {
            unit.startTimes.removeAll { $0.groupID == groupID }
        }
        if let time, let first = orderedUnits.first {
            first.startTimes.append(time)
        }
    }

    /// The coach's note aimed at exactly this group, or an empty string.
    func note(forGroup groupID: String) -> String {
        orderedUnits.lazy.compactMap { $0.groupNotes.first { $0.groupID == groupID }?.text }.first ?? ""
    }

    /// Sets or (when empty) removes this group's note. It's stored on the running unit, or the first unit on days without running.
    func setNote(_ text: String, forGroup groupID: String) {
        for unit in units {
            unit.groupNotes.removeAll { $0.groupID == groupID }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let unit = orderedUnits.first { $0.kind == .running } ?? orderedUnits.first ?? runningUnit()
        unit.groupNotes.append(GroupNote(groupID: groupID, text: text))
    }
}
