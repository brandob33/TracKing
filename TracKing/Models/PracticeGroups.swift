import Foundation

/// Event groups the coach is running together for one session, e.g. Short Sprints + Short Hurdles.
struct GroupCombination: Codable, Hashable {
    var groupIDs: [String]
}

/// A few athletes timed apart from their group for one session, e.g. Brandon and Justin
/// practicing at a different time. Their times still go on the same workout, so they can
/// finish it later, and their usual group carries on without them.
struct DayGroup: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var athleteIDs: [String]

    /// e.g. "Brandon", "Brandon & Justin", or "Brandon, Justin & Marcus".
    static func name(for athletes: [Athlete]) -> String {
        let names = athletes.map { $0.name.isEmpty ? "Unnamed" : $0.name }
        switch names.count {
        case 0: return "Separate Group"
        case 1: return names[0]
        case 2, 3: return names.dropLast().joined(separator: ", ") + " & " + names[names.count - 1]
        default: return "\(names[0]), \(names[1]) + \(names.count - 2)"
        }
    }
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

    /// Times these athletes on their own for this session. They leave any other day group first.
    @discardableResult
    func splitOff(_ athletes: [Athlete]) -> DayGroup {
        let ids = athletes.map(\.athleteID)
        dayGroups = dayGroups
            .map { DayGroup(id: $0.id, name: $0.name, athleteIDs: $0.athleteIDs.filter { !ids.contains($0) }) }
            .filter { !$0.athleteIDs.isEmpty }
        let group = DayGroup(name: DayGroup.name(for: athletes), athleteIDs: ids)
        dayGroups.append(group)
        return group
    }

    /// Sends a day group's athletes back to their usual groups. Times they logged stay.
    func returnToGroups(_ dayGroupID: String) {
        dayGroups.removeAll { $0.id == dayGroupID }
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
    /// Set when this is a few athletes timed apart from their group for the day.
    let dayGroup: DayGroup?
    /// Set when an athlete is timing themselves: the session covers only them.
    let personalAthlete: Athlete?

    /// Stable for the day, e.g. "shortSprint+shortHurdles", "day.<id>" for a day group,
    /// or "self.<athleteID>" for an athlete timing themselves.
    var id: String {
        if let personalAthlete { return "self.\(personalAthlete.athleteID)" }
        return dayGroup.map { "day.\($0.id)" } ?? groupIDs.joined(separator: "+")
    }

    /// Whether this is one athlete timing themselves, rather than a coach timing a group.
    var isPersonal: Bool { personalAthlete != nil }
    /// Athletes in these groups, excluding this device's own profile and anyone timed in a day group.
    let athletes: [Athlete]
    /// Which lane color and number this group gets. It follows the group's place in the coach's
    /// Team list, not its place on the board, so a group keeps its color every day.
    var colorIndex = 0

    init(workout: Workout, groupIDs: [String], allAthletes: [Athlete]) {
        self.workout = workout
        self.groupIDs = groupIDs
        self.dayGroup = nil
        self.personalAthlete = nil
        let splitOff = Set(workout.dayGroups.flatMap(\.athleteIDs))
        self.athletes = allAthletes.filter {
            !$0.isDeviceUser && groupIDs.contains($0.eventGroupID) && !splitOff.contains($0.athleteID)
        }
    }

    init(workout: Workout, dayGroup: DayGroup, allAthletes: [Athlete]) {
        self.workout = workout
        self.dayGroup = dayGroup
        self.personalAthlete = nil
        let members = allAthletes.filter { dayGroup.athleteIDs.contains($0.athleteID) }
        self.athletes = members
        var ids: [String] = []
        for athlete in members where !ids.contains(athlete.eventGroupID) {
            ids.append(athlete.eventGroupID)
        }
        self.groupIDs = ids
    }

    /// One athlete timing themselves, e.g. over the summer or on their own. They see and log
    /// only their own sets.
    init(workout: Workout, personalAthlete athlete: Athlete) {
        self.workout = workout
        self.dayGroup = nil
        self.personalAthlete = athlete
        self.groupIDs = [athlete.eventGroupID]
        self.athletes = [athlete]
    }

    /// Every group (or combination) practicing in a session, earliest start first, then any
    /// day groups. Groups that start at the same time keep the coach's order. A group whose
    /// athletes have all been split off into day groups is left out.
    static func all(in workout: Workout, groups: [EventGroup], athletes: [Athlete]) -> [GroupSession] {
        let splitOff = Set(workout.dayGroups.flatMap(\.athleteIDs))
        let regular = workout.practiceGroups(from: groups)
            .map { GroupSession(workout: workout, groupIDs: $0, allAthletes: athletes) }
            .filter { session in
                let everyone = athletes.filter { !$0.isDeviceUser && session.groupIDs.contains($0.eventGroupID) }
                return !(session.athletes.isEmpty && everyone.contains { splitOff.contains($0.athleteID) })
            }
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
            .map { session -> GroupSession in
                var session = session
                session.colorIndex = groups.firstIndex { $0.groupID == session.groupIDs.first } ?? 0
                return session
            }
        // Day groups take the colors after the last event group's.
        let day = workout.dayGroups.enumerated().map { index, dayGroup -> GroupSession in
            var session = GroupSession(workout: workout, dayGroup: dayGroup, allAthletes: athletes)
            session.colorIndex = groups.count + index
            return session
        }
        return regular + day.filter { !$0.athletes.isEmpty }
    }

    /// What the coach sees: the groups' own plans, plus notes and sets aimed at men, women, or one of the athletes.
    var profile: AthleteProfile {
        if let personalAthlete {
            return personalAthlete.profile
        }
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
        // A day group can mix groups, so each athlete runs only what their own group runs.
        if dayGroup != nil || isPersonal {
            return athletes.filter { $0.profile.canSee(workoutSet.groupID) }
        }
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
