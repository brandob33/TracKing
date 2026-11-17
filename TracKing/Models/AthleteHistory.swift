import Foundation

/// One athlete's logged times, grouped by distance. Used to find their fastest at each
/// distance (a "training best") and what they ran the last time they did that distance.
///
/// These come from workout reps, so they're kept apart from the meet personal records an
/// athlete types into their profile.
struct AthleteHistory {
    struct Entry {
        let seconds: Double
        /// The day of the session the rep was run in.
        let day: Date
    }

    private var entriesByDistance: [Int: [Entry]] = [:]

    init(results: [RepResult], athleteID: String) {
        for result in results where result.athleteID == athleteID {
            guard
                let workoutSet = result.set,
                let distance = workoutSet.distanceMeters,
                let day = workoutSet.unit?.workout?.date
            else { continue }
            entriesByDistance[distance, default: []].append(Entry(seconds: result.seconds, day: day))
        }
    }

    /// The athlete's fastest time at each distance they've logged, shortest distance first.
    var bests: [(distance: Int, entry: Entry)] {
        entriesByDistance
            .compactMap { distance, entries in
                entries.min { $0.seconds < $1.seconds }.map { (distance: distance, entry: $0) }
            }
            .sorted { $0.distance < $1.distance }
    }

    /// Whether this time is the athlete's fastest at its distance. A first-ever time at a
    /// distance doesn't count, since there's nothing yet to beat.
    func isBest(_ result: RepResult) -> Bool {
        guard
            let distance = result.set?.distanceMeters,
            let entries = entriesByDistance[distance],
            entries.count > 1,
            let fastest = entries.map(\.seconds).min()
        else { return false }
        return result.seconds <= fastest
    }

    /// The fastest rep at this distance from the most recent session before `day`.
    func lastTime(at distance: Int?, before day: Date, calendar: Calendar = .current) -> Double? {
        guard let distance, let entries = entriesByDistance[distance] else { return nil }
        let cutoff = calendar.startOfDay(for: day)
        let earlier = entries.filter { $0.day < cutoff }
        guard let lastDay = earlier.map(\.day).max() else { return nil }
        return earlier
            .filter { calendar.isDate($0.day, inSameDayAs: lastDay) }
            .map(\.seconds)
            .min()
    }
}
