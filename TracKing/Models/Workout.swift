import Foundation
import SwiftData

// MARK: - Training week

/// One week (microcycle) of the coach's plan, with the info from the top of the plan sheet.
@Model
final class TrainingWeek {
    /// The Monday the week starts on.
    var startDate: Date
    var teamName: String
    var season: String
    var phase: String
    var mesocycle: Int
    var microcycle: Int
    /// The week's emphasis, e.g. "Deload". Empty for a normal week.
    var focus: String
    var location: String
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \Workout.week)
    var workouts: [Workout] = []

    init(
        startDate: Date,
        teamName: String,
        season: String = "",
        phase: String,
        mesocycle: Int,
        microcycle: Int,
        focus: String = "",
        location: String = "",
        notes: String = ""
    ) {
        self.startDate = startDate
        self.teamName = teamName
        self.season = season
        self.phase = phase
        self.mesocycle = mesocycle
        self.microcycle = microcycle
        self.focus = focus
        self.location = location
        self.notes = notes
    }

    /// e.g. "General Prep · Meso 4 · Micro 4"
    var cycleSummary: String {
        [phase, "Meso \(mesocycle)", "Micro \(microcycle)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let end = calendar.date(byAdding: .day, value: 7, to: startDate) else { return false }
        return date >= startDate && date < end
    }
}

// MARK: - Workout (session)

/// One day's session: an ordered list of units, like the columns of the plan sheet.
@Model
final class Workout {
    var date: Date
    var sessionNumber: Int
    var title: String
    var notes: String
    var location: String
    /// Event groups the coach is running together this session (see `PracticeGroups.swift`).
    var groupCombinations: [GroupCombination] = []
    /// Athletes the coach is timing apart from their group for this session only (see `PracticeGroups.swift`).
    var dayGroups: [DayGroup] = []
    var week: TrainingWeek?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutUnit.workout)
    var units: [WorkoutUnit] = []

    init(
        date: Date,
        sessionNumber: Int,
        title: String,
        notes: String = "",
        location: String = "",
        units: [WorkoutUnit] = []
    ) {
        self.date = date
        self.sessionNumber = sessionNumber
        self.title = title
        self.notes = notes
        self.location = location
        self.units = units
    }

    /// SwiftData relationships are unordered, so sort by the stored order.
    var orderedUnits: [WorkoutUnit] {
        units.sorted { $0.order < $1.order }
    }

    /// When this athlete should arrive: the first unit with a start time that applies to them.
    func startTime(for profile: AthleteProfile) -> Date? {
        for unit in orderedUnits {
            if let time = profile.bestMatch(in: unit.startTimes, groupID: \.groupID) {
                return time.date(on: date)
            }
        }
        return nil
    }

    /// The sets this athlete is meant to run, across all units, in order.
    func visibleSets(for profile: AthleteProfile) -> [WorkoutSet] {
        orderedUnits.flatMap { $0.orderedSets.filter { profile.canSee($0.groupID) } }
    }

    /// Number of reps with a logged time among this athlete's sets.
    func loggedRepCount(for profile: AthleteProfile) -> Int {
        visibleSets(for: profile).reduce(0) { $0 + $1.results(forAthlete: profile.athleteID).count }
    }
}

// MARK: - Units

/// The category of a unit, used for its icon.
enum UnitKind: String, Codable, CaseIterable {
    case warmUp
    case running
    case mobility
    case drills
    case plyometrics
    case strength
    case coolDown
    case rehab
    case recovery
    case lifestyle
    case activeRest

    var systemImage: String {
        switch self {
        case .warmUp: "flame.fill"
        case .running: "figure.run"
        case .mobility: "figure.flexibility"
        case .drills: "figure.walk"
        case .plyometrics: "figure.jumprope"
        case .strength: "dumbbell.fill"
        case .coolDown: "wind"
        case .rehab: "cross.case.fill"
        case .recovery: "snowflake"
        case .lifestyle: "moon.zzz.fill"
        case .activeRest: "figure.pool.swim"
        }
    }
}

/// A start time for a group, e.g. "MEN 1:15PM". A `nil` group means everyone.
struct GroupStartTime: Codable, Hashable {
    var groupID: String?
    var hour: Int
    var minute: Int

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

/// A coach note, optionally aimed at one group or athlete.
struct GroupNote: Codable, Hashable {
    var groupID: String?
    var text: String
}

/// A non-running exercise, e.g. "Hip Thrust Complex = 2 Sets + 8 Reps".
struct UnitExercise: Codable, Hashable {
    var name: String
    var sets: Int
    var reps: Int
    var notes: String = ""
}

/// One numbered unit of a session, e.g. "1. Warm Up" or "2. Speed Endurance".
@Model
final class WorkoutUnit {
    var order: Int
    var kind: UnitKind
    var title: String
    var details: String
    /// Names of routines from the series library, e.g. "Warm Up Series A".
    var seriesNames: [String] = []
    var startTimes: [GroupStartTime] = []
    var groupNotes: [GroupNote] = []
    var exercises: [UnitExercise] = []
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.unit)
    var sets: [WorkoutSet] = []

    init(
        order: Int,
        kind: UnitKind,
        title: String,
        details: String = "",
        seriesNames: [String] = [],
        startTimes: [GroupStartTime] = [],
        groupNotes: [GroupNote] = [],
        exercises: [UnitExercise] = [],
        sets: [WorkoutSet] = []
    ) {
        self.order = order
        self.kind = kind
        self.title = title
        self.details = details
        self.seriesNames = seriesNames
        self.startTimes = startTimes
        self.groupNotes = groupNotes
        self.exercises = exercises
        self.sets = sets
    }

    var orderedSets: [WorkoutSet] {
        sets.sorted { $0.order < $1.order }
    }
}

// MARK: - Sets and results

/// A goal for a group, e.g. "M: (13.5) 16.0" or a range like "M: 9-10".
struct GroupTarget: Codable, Hashable {
    var groupID: String?
    /// Pace per 100m in seconds, the number in parentheses on the plan.
    var pacePer100: Double?
    var goalSeconds: Double
    /// Upper end of the goal when the coach gives a range.
    var goalMaxSeconds: Double?

    var goalText: String {
        if let goalMaxSeconds {
            return "\(TimeFormatting.compact(goalSeconds))–\(TimeFormatting.compact(goalMaxSeconds))"
        }
        return TimeFormatting.entry(goalSeconds)
    }

    /// Compares a logged time to this goal. Within a range, or within 0.05s of a single goal, is on target.
    func compare(_ seconds: Double) -> GoalComparison {
        let upper = goalMaxSeconds ?? goalSeconds
        if seconds < goalSeconds - 0.05 {
            return .faster(by: goalSeconds - seconds)
        }
        if seconds > upper + 0.05 {
            return .slower(by: seconds - upper)
        }
        return .onTarget
    }
}

/// How a logged time compares to the coach's goal.
enum GoalComparison: Equatable {
    case faster(by: Double)
    case onTarget
    case slower(by: Double)
}

/// A block of reps, e.g. "SS: 2 × 120m @ 85% on grass, 6:00 rest", or "3 × 2 × 50m".
@Model
final class WorkoutSet {
    var order: Int
    /// Short label from the coach, e.g. "SS", "LS", or "Accelerations".
    var label: String
    /// Number of sets; reps are repeated this many times.
    var setCount: Int
    var reps: Int
    var distanceMeters: Int?
    var intensityPercent: Int?
    var surface: String
    /// Rest between reps.
    var restSeconds: Int
    /// Rest between sets, when there's more than one.
    var setRestSeconds: Int
    var notes: String
    /// The group or athlete this set is for; `nil` means everyone.
    var groupID: String?
    var targets: [GroupTarget] = []
    var unit: WorkoutUnit?

    @Relationship(deleteRule: .cascade, inverse: \RepResult.set)
    var results: [RepResult] = []

    init(
        order: Int,
        label: String = "",
        setCount: Int = 1,
        reps: Int,
        distanceMeters: Int? = nil,
        intensityPercent: Int? = nil,
        surface: String = "",
        restSeconds: Int = 0,
        setRestSeconds: Int = 0,
        notes: String = "",
        groupID: String? = nil,
        targets: [GroupTarget] = []
    ) {
        self.order = order
        self.label = label
        self.setCount = setCount
        self.reps = reps
        self.distanceMeters = distanceMeters
        self.intensityPercent = intensityPercent
        self.surface = surface
        self.restSeconds = restSeconds
        self.setRestSeconds = setRestSeconds
        self.notes = notes
        self.groupID = groupID
        self.targets = targets
    }

    var totalReps: Int {
        max(setCount, 1) * max(reps, 1)
    }

    /// What one rep is called: "120m", or the label when there's no distance.
    var repName: String {
        distanceMeters.map { "\($0)m" } ?? label
    }

    /// e.g. "2 × 120m" or "3 × 2 × 50m"
    var repsAndDistance: String {
        setCount > 1 ? "\(setCount) × \(reps) × \(repName)" : "\(reps) × \(repName)"
    }

    /// e.g. "SS · 2 × 120m · 85% · Grass"
    var summary: String {
        [
            distanceMeters == nil ? nil : (label.isEmpty ? nil : label),
            repsAndDistance,
            intensityPercent.map { "\($0)%" },
            surface.isEmpty ? nil : surface,
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    /// Which set a rep (1-based, counted across all sets) belongs to.
    func setNumber(forRep repNumber: Int) -> Int {
        (repNumber - 1) / max(reps, 1) + 1
    }

    /// Rest after a rep: the between-set rest at the end of a set, otherwise the between-rep rest.
    func restSeconds(afterRep repNumber: Int) -> Int {
        if setCount > 1, setRestSeconds > 0, repNumber % max(reps, 1) == 0 {
            return setRestSeconds
        }
        return restSeconds
    }

    /// One athlete's logged result for a rep (1-based), if one exists.
    func result(forRep repNumber: Int, athleteID: String) -> RepResult? {
        results.first { $0.repNumber == repNumber && $0.athleteID == athleteID }
    }

    /// Every rep one athlete has logged in this set.
    func results(forAthlete athleteID: String) -> [RepResult] {
        results.filter { $0.athleteID == athleteID }
    }

    /// Saves a typed time for one athlete's rep. Valid times are saved as they're typed;
    /// clearing the text removes the logged time; anything else (e.g. "1:") is ignored.
    func logTime(_ text: String, rep repNumber: Int, athleteID: String, byCoach: Bool, in context: ModelContext) {
        if let seconds = TimeFormatting.parse(text) {
            logSeconds(seconds, rep: repNumber, athleteID: athleteID, byCoach: byCoach)
        } else if text.trimmingCharacters(in: .whitespaces).isEmpty {
            clearResult(rep: repNumber, athleteID: athleteID, in: context)
        }
    }

    /// Saves or replaces one athlete's time for a rep, kept to the hundredth.
    ///
    /// - Note: Once athletes have their own accounts, a coach-logged time saved here should
    ///   also show up in that athlete's account automatically (in Firestore, the result is
    ///   stored once under the team and read by both the coach and the athlete).
    func logSeconds(_ seconds: Double, rep repNumber: Int, athleteID: String, byCoach: Bool) {
        let rounded = (seconds * 100).rounded() / 100
        if let existing = result(forRep: repNumber, athleteID: athleteID) {
            existing.seconds = rounded
            existing.loggedAt = .now
            existing.loggedByCoach = byCoach
        } else {
            results.append(RepResult(repNumber: repNumber, seconds: rounded, athleteID: athleteID, loggedByCoach: byCoach))
        }
    }

    /// Removes one athlete's time for a rep, if there is one.
    func clearResult(rep repNumber: Int, athleteID: String, in context: ModelContext) {
        if let existing = result(forRep: repNumber, athleteID: athleteID) {
            context.delete(existing)
        }
    }
}

/// A time logged for a single rep of a set, by one athlete.
@Model
final class RepResult {
    /// 1-based rep number, counted across all sets.
    var repNumber: Int
    var seconds: Double
    var loggedAt: Date
    /// The athlete who ran the rep (`Athlete.athleteID`).
    var athleteID: String = ""
    /// Whether the coach entered this time rather than the athlete.
    var loggedByCoach: Bool = false
    var set: WorkoutSet?

    init(repNumber: Int, seconds: Double, athleteID: String, loggedByCoach: Bool = false, loggedAt: Date = .now) {
        self.repNumber = repNumber
        self.seconds = seconds
        self.athleteID = athleteID
        self.loggedByCoach = loggedByCoach
        self.loggedAt = loggedAt
    }
}

// MARK: - Series library

/// A named routine the coach defines once, e.g. "Warm Up Series A", and references from workouts.
@Model
final class RoutineSeries {
    @Attribute(.unique) var name: String
    var kind: UnitKind
    var drills: [String]
    var notes: String

    init(name: String, kind: UnitKind, drills: [String], notes: String = "") {
        self.name = name
        self.kind = kind
        self.drills = drills
        self.notes = notes
    }
}

// MARK: - Formatting

/// Formatting helpers for track times.
enum TimeFormatting {
    /// Formats a race time: "28.5s" under a minute, otherwise "2:15.0".
    static func raceTime(_ seconds: Double, fractionDigits: Int = 1) -> String {
        if seconds < 60 {
            return seconds.formatted(.number.precision(.fractionLength(fractionDigits))) + "s"
        }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        let secondsText = remainder.formatted(.number.precision(.integerAndFractionLength(integer: 2, fraction: fractionDigits)))
        return "\(minutes):\(secondsText)"
    }

    /// Formats a time the way an athlete types it: "28.5", "15.84", or "1:08.4".
    /// Keeps hundredths when there are any, so stopwatch times aren't rounded when shown in a field.
    static func entry(_ seconds: Double) -> String {
        let style = FloatingPointFormatStyle<Double>.number
            .locale(Locale(identifier: "en_US_POSIX"))
        if seconds < 60 {
            return seconds.formatted(style.precision(.fractionLength(1...2)))
        }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return "\(minutes):" + remainder.formatted(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 1...2)))
    }

    /// A stopwatch reading, always to the hundredth: "15.84" or "1:08.40".
    static func stopwatch(_ seconds: Double) -> String {
        let style = FloatingPointFormatStyle<Double>.number
            .locale(Locale(identifier: "en_US_POSIX"))
            .rounded(rule: .down)
        if seconds < 60 {
            return seconds.formatted(style.precision(.fractionLength(2)))
        }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return "\(minutes):" + remainder.formatted(style.precision(.integerAndFractionLength(integer: 2, fraction: 2)))
    }

    /// Like `entry`, but drops a trailing ".0": "9", "13.5", "2:30".
    static func compact(_ seconds: Double) -> String {
        guard seconds.rounded() == seconds else { return entry(seconds) }
        let whole = Int(seconds)
        if whole < 60 {
            return "\(whole)"
        }
        let remainder = whole % 60
        return "\(whole / 60):" + (remainder < 10 ? "0\(remainder)" : "\(remainder)")
    }

    /// Parses athlete input like "28.5", "28,5s", or "1:08.4" into seconds.
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: CharacterSet(charactersIn: "sS"))
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)

        let seconds: Double?
        switch parts.count {
        case 1:
            seconds = Double(parts[0])
        case 2:
            if let minutes = Int(parts[0]), let secs = Double(parts[1]), secs < 60 {
                seconds = Double(minutes * 60) + secs
            } else {
                seconds = nil
            }
        default:
            seconds = nil
        }

        guard let seconds, seconds > 0 else { return nil }
        return seconds
    }

    /// Formats a rest interval as "m:ss".
    static func rest(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
