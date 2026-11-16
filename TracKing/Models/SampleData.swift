import Foundation
import SwiftData

/// Placeholder data modeled on a real weekly plan, until coaches can create and send their own.
enum SampleData {
    static let modelTypes: [any PersistentModel.Type] = [TrainingWeek.self, Workout.self, RoutineSeries.self, Athlete.self, EventGroup.self]

    /// Inserts sample weeks, the series library, and the starting event groups the first time the app launches.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        // Checked separately so installs from before event groups existed still get them.
        let groupCount = (try? context.fetchCount(FetchDescriptor<EventGroup>())) ?? 0
        if groupCount == 0 {
            EventGroup.defaults().forEach { context.insert($0) }
        }

        // Checked separately so installs from before the roster existed still get one.
        let rosterCount = (try? context.fetchCount(FetchDescriptor<Athlete>(predicate: #Predicate { !$0.isDeviceUser }))) ?? 0
        if rosterCount == 0 {
            roster().forEach { context.insert($0) }
        }

        let existingCount = (try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0
        guard existingCount == 0 else { return }
        seriesLibrary().forEach { context.insert($0) }
        makeWeeks().forEach { context.insert($0) }
    }

    /// An in-memory container populated with sample data for previews.
    @MainActor
    static let previewContainer: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: Schema(modelTypes),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            insertAll(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()

    @MainActor
    private static func insertAll(into context: ModelContext) {
        EventGroup.defaults().forEach { context.insert($0) }
        roster().forEach { context.insert($0) }
        seriesLibrary().forEach { context.insert($0) }
        makeWeeks().forEach { context.insert($0) }
    }

    /// Teammates for the coach to time, until athletes sign in with their own accounts.
    static func roster() -> [Athlete] {
        let men = TrainingGroup.men.id
        let women = TrainingGroup.women.id
        return [
            Athlete(name: "Justin", genderGroupID: men, eventGroupID: TrainingGroup.shortSprint.id),
            Athlete(name: "Brandon", genderGroupID: men, eventGroupID: TrainingGroup.shortSprint.id),
            Athlete(name: "Marcus", genderGroupID: men, eventGroupID: TrainingGroup.shortSprint.id),
            Athlete(name: "Sara", genderGroupID: women, eventGroupID: TrainingGroup.shortSprint.id),
            Athlete(name: "Jordan", genderGroupID: women, eventGroupID: TrainingGroup.shortSprint.id),
            Athlete(name: "Macaria", genderGroupID: women, eventGroupID: TrainingGroup.longSprint.id),
            Athlete(name: "Devon", genderGroupID: men, eventGroupID: TrainingGroup.longSprint.id),
            Athlete(name: "Ava", genderGroupID: women, eventGroupID: TrainingGroup.shortHurdles.id),
            Athlete(name: "Tyler", genderGroupID: men, eventGroupID: TrainingGroup.longHurdles.id),
        ]
    }

    // MARK: - Weeks

    /// The current week plus the weeks before and after, all using the same plan.
    static func makeWeeks(around referenceDate: Date = .now, calendar: Calendar = .current) -> [TrainingWeek] {
        let today = calendar.startOfDay(for: referenceDate)
        // Monday is weekday 2 in the Gregorian calendar.
        let daysSinceMonday = (calendar.component(.weekday, from: today) - 2 + 7) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return [] }

        return (-1...1).compactMap { weekOffset in
            guard let monday = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday) else { return nil }
            let week = TrainingWeek(
                startDate: monday,
                teamName: "UCI SPR + HUR",
                season: "26-27",
                phase: "General Prep",
                mesocycle: 4,
                microcycle: 4 + weekOffset,
                focus: weekOffset == 0 ? "Deload" : "",
                notes: "Sundays: Rest"
            )
            week.workouts = makeSessions(startingOn: monday, calendar: calendar)
            return week
        }
    }

    /// Monday through Saturday sessions. Sunday is a rest day, so it has no workout.
    private static func makeSessions(startingOn monday: Date, calendar: Calendar) -> [Workout] {
        let builders = [monday1, tuesday2, wednesday3, thursday4, friday5, saturday6]
        return builders.enumerated().compactMap { offset, build in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday),
                  let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) else { return nil }
            return build(noon)
        }
    }

    // MARK: - Shared units

    private static let men = TrainingGroup.men.id
    private static let women = TrainingGroup.women.id
    private static let shortHurdles = TrainingGroup.shortHurdles.id
    private static let longHurdles = TrainingGroup.longHurdles.id
    private static let shortSprint = TrainingGroup.shortSprint.id
    private static let longSprint = TrainingGroup.longSprint.id

    private static func nutritionAndSleep(order: Int) -> WorkoutUnit {
        WorkoutUnit(order: order, kind: .lifestyle, title: "Quality Nutrition + Quality Sleep")
    }

    private static func liftWeights(order: Int) -> WorkoutUnit {
        WorkoutUnit(order: order, kind: .strength, title: "Lift Weights")
    }

    private static func rollOutAndIceBath(order: Int) -> WorkoutUnit {
        WorkoutUnit(order: order, kind: .recovery, title: "Roll Out + Ice Bath", details: "Roll out for 15 minutes, then ice bath.")
    }

    // MARK: - Sessions

    private static func monday1(_ date: Date) -> Workout {
        Workout(date: date, sessionNumber: 1, title: "Acceleration Development", units: [
            WorkoutUnit(
                order: 0, kind: .warmUp, title: "Warm Up",
                details: "BRING SPIKES (Finesse only, or spikes from your former school). Sprint Drills A: omit the last 2 drills and implement Accel Sprint Drills A.",
                seriesNames: ["Band Series 1", "Warm Up Series A", "Sprint Drills A", "Accel Sprint Drills A"],
                startTimes: [GroupStartTime(hour: 13, minute: 30)]
            ),
            WorkoutUnit(
                order: 1, kind: .running, title: "Acceleration Development",
                groupNotes: [
                    GroupNote(groupID: shortHurdles, text: "Hurdlers = above (6 accels) + drills."),
                    GroupNote(groupID: longHurdles, text: "Hurdlers = above (6 accels) + drills."),
                    GroupNote(groupID: TrainingGroup.athlete("Macaria").id, text: "Drills specific to HJ."),
                ],
                sets: [
                    WorkoutSet(order: 0, label: "Accelerations", reps: 8),
                    WorkoutSet(order: 1, reps: 4, distanceMeters: 35, restSeconds: 240),
                ]
            ),
            WorkoutUnit(order: 2, kind: .coolDown, title: "Cool Down", seriesNames: ["Cool Down Series C"]),
            WorkoutUnit(order: 3, kind: .drills, title: "Walking Drills", seriesNames: ["Walking Drills Series A"]),
            liftWeights(order: 4),
            rollOutAndIceBath(order: 5),
            nutritionAndSleep(order: 6),
        ])
    }

    private static func tuesday2(_ date: Date) -> Workout {
        Workout(date: date, sessionNumber: 2, title: "Speed Endurance", units: [
            WorkoutUnit(
                order: 0, kind: .warmUp, title: "Warm Up",
                seriesNames: ["Warm Up Series C"],
                startTimes: [
                    GroupStartTime(groupID: men, hour: 13, minute: 15),
                    GroupStartTime(groupID: women, hour: 14, minute: 15),
                    GroupStartTime(groupID: TrainingGroup.athlete("Sara").id, hour: 10, minute: 0),
                    GroupStartTime(groupID: TrainingGroup.athlete("Justin").id, hour: 11, minute: 0),
                    GroupStartTime(groupID: TrainingGroup.athlete("Brandon").id, hour: 11, minute: 0),
                ]
            ),
            WorkoutUnit(
                order: 1, kind: .running, title: "Speed Endurance",
                sets: [
                    WorkoutSet(
                        order: 0, label: "SS", reps: 2, distanceMeters: 120, intensityPercent: 85, surface: "Grass", restSeconds: 360,
                        groupID: shortSprint,
                        targets: [
                            GroupTarget(groupID: men, pacePer100: 13.5, goalSeconds: 16.0),
                            GroupTarget(groupID: women, pacePer100: 14.5, goalSeconds: 17.5),
                        ]
                    ),
                    WorkoutSet(
                        order: 1, label: "SS", reps: 3, distanceMeters: 80, intensityPercent: 85, surface: "Grass", restSeconds: 240,
                        groupID: shortSprint,
                        targets: [
                            GroupTarget(groupID: men, goalSeconds: 9, goalMaxSeconds: 10),
                            GroupTarget(groupID: women, goalSeconds: 10, goalMaxSeconds: 11),
                        ]
                    ),
                    WorkoutSet(
                        order: 2, label: "LS", reps: 3, distanceMeters: 300, intensityPercent: 80, surface: "Grass", restSeconds: 420,
                        groupID: longSprint,
                        targets: [
                            GroupTarget(groupID: men, pacePer100: 15.0, goalSeconds: 45),
                            GroupTarget(groupID: women, pacePer100: 17.0, goalSeconds: 51),
                        ]
                    ),
                    WorkoutSet(
                        order: 3, label: "LS", reps: 2, distanceMeters: 150, intensityPercent: 80, surface: "Grass", restSeconds: 300,
                        groupID: longSprint,
                        targets: [
                            GroupTarget(groupID: men, pacePer100: 14, goalSeconds: 17, goalMaxSeconds: 18),
                            GroupTarget(groupID: women, pacePer100: 16, goalSeconds: 20, goalMaxSeconds: 21),
                        ]
                    ),
                    WorkoutSet(
                        order: 4, setCount: 3, reps: 2, distanceMeters: 50, restSeconds: 180,
                        groupID: TrainingGroup.athlete("Macaria").id
                    ),
                ]
            ),
            WorkoutUnit(order: 2, kind: .coolDown, title: "Cool Down", seriesNames: ["Cool Down Series B"]),
            WorkoutUnit(order: 3, kind: .mobility, title: "Hurdle Mobility", seriesNames: ["Hurdle Mobility Series E"]),
            WorkoutUnit(order: 4, kind: .recovery, title: "Roll + Stretch + Contrast"),
            nutritionAndSleep(order: 5),
        ])
    }

    private static func wednesday3(_ date: Date) -> Workout {
        Workout(date: date, sessionNumber: 3, title: "Mobility & Muscle Activation", units: [
            WorkoutUnit(
                order: 0, kind: .warmUp, title: "Warm Up",
                seriesNames: ["Jog Mobility Series C"],
                startTimes: [GroupStartTime(hour: 14, minute: 15)]
            ),
            WorkoutUnit(
                order: 1, kind: .mobility, title: "Mobility – Muscle Activation",
                exercises: [
                    UnitExercise(name: "Hip Thrust Complex", sets: 2, reps: 8, notes: "Complete Russian hamstrings with a partner."),
                    UnitExercise(name: "Superman Complex", sets: 2, reps: 12),
                ]
            ),
            WorkoutUnit(order: 2, kind: .rehab, title: "Shin Health", seriesNames: ["Shin Circuit"]),
            liftWeights(order: 3),
            WorkoutUnit(order: 4, kind: .recovery, title: "Stretch + Foam Roll", details: "20 minutes."),
        ])
    }

    private static func thursday4(_ date: Date) -> Workout {
        let workout = Workout(date: date, sessionNumber: 4, title: "Technical Running + Plyos", units: [
            WorkoutUnit(
                order: 0, kind: .warmUp, title: "Warm Up",
                seriesNames: ["Warm Up Series B"],
                startTimes: [
                    GroupStartTime(groupID: men, hour: 13, minute: 15),
                    GroupStartTime(groupID: women, hour: 14, minute: 15),
                ]
            ),
            WorkoutUnit(
                order: 1, kind: .plyometrics, title: "Technical Running + Plyos + Med Ball Throws",
                details: "Speed drills + box jumps + med ball throws.",
                groupNotes: [
                    GroupNote(groupID: shortHurdles, text: "Hurdlers = above + drills."),
                    GroupNote(groupID: longHurdles, text: "Hurdlers = above + drills."),
                ]
            ),
            WorkoutUnit(order: 2, kind: .coolDown, title: "Cool Down", seriesNames: ["Cool Down Series A"]),
            WorkoutUnit(order: 3, kind: .drills, title: "Walking Drills", seriesNames: ["Walking Drills Series B"]),
            rollOutAndIceBath(order: 4),
            nutritionAndSleep(order: 5),
        ])
        // "Hurdlers = above + drills": short hurdlers run with the short sprinters today.
        workout.combine([TrainingGroup.shortSprint.id, shortHurdles])
        return workout
    }

    private static func friday5(_ date: Date) -> Workout {
        Workout(date: date, sessionNumber: 5, title: "Workout", location: "Track", units: [
            WorkoutUnit(
                order: 0, kind: .warmUp, title: "Warm Up",
                details: "TBD. Meet at the track.",
                startTimes: [GroupStartTime(hour: 13, minute: 30)]
            ),
            WorkoutUnit(order: 1, kind: .running, title: "Workout", details: "TBD"),
            WorkoutUnit(order: 2, kind: .coolDown, title: "Cool Down", details: "TBD"),
            liftWeights(order: 3),
            WorkoutUnit(order: 4, kind: .recovery, title: "Stretch + Contrast"),
            nutritionAndSleep(order: 5),
        ])
    }

    private static func saturday6(_ date: Date) -> Workout {
        Workout(date: date, sessionNumber: 6, title: "Active Rest", units: [
            WorkoutUnit(
                order: 0, kind: .activeRest, title: "Full or Optional Active Rest",
                details: "Swim for 15 minutes, bike for 10 minutes, or take a yoga class."
            ),
        ])
    }

    // MARK: - Series library

    /// Example drills so each series has something to show. The coach will define the real ones.
    static func seriesLibrary() -> [RoutineSeries] {
        [
            RoutineSeries(name: "Band Series 1", kind: .warmUp, drills: [
                "Lateral band walks, 2 × 10m", "Monster walks, 2 × 10m", "Glute bridges with band, 15",
            ]),
            RoutineSeries(name: "Warm Up Series A", kind: .warmUp, drills: [
                "800m jog", "Leg swings, front and side, 10 each", "Walking lunges, 20m", "A-skips, 2 × 20m", "3 × 60m build-ups",
            ]),
            RoutineSeries(name: "Warm Up Series B", kind: .warmUp, drills: [
                "600m jog", "Hip circuit", "High knees, 2 × 20m", "B-skips, 2 × 20m", "2 × 60m build-ups",
            ]),
            RoutineSeries(name: "Warm Up Series C", kind: .warmUp, drills: [
                "800m jog", "Dynamic stretching circuit", "Carioca, 2 × 20m", "Straight-leg bounds, 2 × 20m", "3 × 80m build-ups",
            ]),
            RoutineSeries(name: "Jog Mobility Series C", kind: .warmUp, drills: [
                "10 minute easy jog", "Hip openers and closers", "World's greatest stretch, 5 per side",
            ]),
            RoutineSeries(name: "Sprint Drills A", kind: .drills, drills: [
                "A-march", "A-skip", "B-skip", "Fast leg", "Straight-leg bound", "Dribbles",
            ]),
            RoutineSeries(name: "Accel Sprint Drills A", kind: .drills, drills: [
                "Wall drives, 3 × 5", "Falling starts, 3 × 10m", "Half-kneeling starts, 3 × 10m",
            ]),
            RoutineSeries(name: "Cool Down Series A", kind: .coolDown, drills: ["800m easy jog", "Static stretching, 10 minutes"]),
            RoutineSeries(name: "Cool Down Series B", kind: .coolDown, drills: ["1200m easy jog", "Static stretching, 10 minutes"]),
            RoutineSeries(name: "Cool Down Series C", kind: .coolDown, drills: ["4 × 100m barefoot strides on grass", "Static stretching, 10 minutes"]),
            RoutineSeries(name: "Walking Drills Series A", kind: .drills, drills: ["Heel walks, 20m", "Toe walks, 20m", "Walking A-march, 2 × 20m"]),
            RoutineSeries(name: "Walking Drills Series B", kind: .drills, drills: ["Inverted hamstring walks, 20m", "Walking quad pulls, 20m", "Lateral lunges, 20m"]),
            RoutineSeries(name: "Hurdle Mobility Series E", kind: .mobility, drills: [
                "Lead-leg walkovers, 2 × 6 hurdles", "Trail-leg walkovers, 2 × 6 hurdles", "Over-unders, 2 × 6 hurdles",
            ]),
            RoutineSeries(name: "Shin Circuit", kind: .rehab, drills: [
                "Toe raises, 2 × 20", "Heel walks, 2 × 20m", "Ankle alphabet, each foot", "Banded dorsiflexion, 2 × 15",
            ]),
        ]
    }
}
