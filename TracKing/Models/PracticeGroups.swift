import Foundation

/// Event groups the coach is running together for one session, e.g. Short Sprints + Short Hurdles.
struct GroupCombination: Codable, Hashable {
    var groupIDs: [String]
}

extension Workout {
    /// The groups practicing in this session, in the coach's order. Combined groups come back
    /// as one entry, placed where their first group would be.
    func practiceGroups(from groups: [EventGroup]) -> [[String]] {
        var result: [[String]] = []
        var placed = Set<String>()
        for group in groups where !placed.contains(group.groupID) {
            let combined = groupCombinations.first { $0.groupIDs.contains(group.groupID) }?.groupIDs ?? [group.groupID]
            // Keep the coach's group order inside a combination too.
            let ordered = groups.map(\.groupID).filter { combined.contains($0) }
            result.append(ordered.isEmpty ? [group.groupID] : ordered)
            placed.formUnion(combined)
        }
        return result
    }

    /// Runs these groups together for this session. A group can only be in one combination,
    /// so it's taken out of any other first.
    func combine(_ groupIDs: [String]) {
        separate(groupIDs)
        guard groupIDs.count > 1 else { return }
        groupCombinations.append(GroupCombination(groupIDs: groupIDs))
    }

    /// Takes these groups out of any combination, so each runs on its own again.
    func separate(_ groupIDs: [String]) {
        groupCombinations = groupCombinations
            .map { GroupCombination(groupIDs: $0.groupIDs.filter { !groupIDs.contains($0) }) }
            .filter { $0.groupIDs.count > 1 }
    }
}

/// One or more event groups running a session together: who's in it, what they see, and
/// who runs each set. Shared by the coach's Today list and the timing screen.
struct GroupSession: Identifiable {
    let workout: Workout
    let groupIDs: [String]

    /// Stable for the day, e.g. "shortSprint+shortHurdles".
    var id: String { groupIDs.joined(separator: "+") }
    /// Athletes in these groups, excluding this device's own profile.
    let athletes: [Athlete]

    init(workout: Workout, groupIDs: [String], allAthletes: [Athlete]) {
        self.workout = workout
        self.groupIDs = groupIDs
        self.athletes = allAthletes.filter { !$0.isDeviceUser && groupIDs.contains($0.eventGroupID) }
    }

    /// Every group (or combination) practicing in a session, earliest start first.
    /// Groups that start at the same time keep the coach's order.
    static func all(in workout: Workout, groups: [EventGroup], athletes: [Athlete]) -> [GroupSession] {
        workout.practiceGroups(from: groups)
            .map { GroupSession(workout: workout, groupIDs: $0, allAthletes: athletes) }
            .enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.startTime, rhs.element.startTime) {
                case let (left?, right?) where left != right: left < right
                case (_?, nil): true
                case (nil, _?): false
                default: lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    /// What the coach sees: the groups' own plans, plus notes and sets aimed at men, women, or one of the athletes.
    var profile: AthleteProfile {
        let athleteGroupIDs = athletes.compactMap { athlete in
            athlete.profile.groupIDs.first { $0.hasPrefix("athlete.") }
        }
        return AthleteProfile(name: "", groupIDs: groupIDs + [TrainingGroup.men.id, TrainingGroup.women.id] + athleteGroupIDs)
    }

    /// Every timed set for these groups, in order.
    var sets: [WorkoutSet] {
        workout.visibleSets(for: profile)
    }

    /// Who runs a set. When groups are combined they run the same workout, so a set written
    /// for any of them is run by all of them. Sets aimed at men, women, or one athlete stay with them.
    func athletes(for workoutSet: WorkoutSet) -> [Athlete] {
        guard let setGroupID = workoutSet.groupID, !groupIDs.contains(setGroupID) else { return athletes }
        return athletes.filter { $0.profile.canSee(setGroupID) }
    }

    /// The earliest start time among these groups: a group's own time, else the session's
    /// general time, else the men's or women's time for the athletes in the group.
    var startTime: Date? {
        let times = groupIDs.compactMap { groupID -> Date? in
            if let own = workout.startTime(forGroup: groupID) {
                return own.date(on: workout.date)
            }
            return nil
        }
        if let earliest = times.min() {
            return earliest
        }
        let genderIDs = Set(athletes.map(\.genderGroupID))
        let profile = AthleteProfile(name: "", groupIDs: Array(genderIDs).sorted())
        let candidates = workout.orderedUnits.flatMap(\.startTimes).filter { $0.groupID == nil || profile.canSee($0.groupID) }
        return candidates.map { $0.date(on: workout.date) }.min()
    }

    /// Reps the coach still has to time: one per athlete per rep.
    var expectedRepCount: Int {
        sets.reduce(0) { $0 + $1.totalReps * athletes(for: $1).count }
    }

    var loggedRepCount: Int {
        sets.reduce(0) { total, workoutSet in
            let runnerIDs = Set(athletes(for: workoutSet).map(\.athleteID))
            return total + workoutSet.results.count { runnerIDs.contains($0.athleteID) }
        }
    }
}
