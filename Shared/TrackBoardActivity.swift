import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/// What the lock screen and Dynamic Island show while groups are running or resting.
/// Shared by the app (which starts and updates the activity) and the widget extension (which draws it).
nonisolated struct TrackBoardActivityAttributes: Codable, Hashable, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var lanes: [LaneStatus]

        /// Resting groups first, the one due back on the line soonest at the top; then running groups.
        var sortedLanes: [LaneStatus] {
            lanes.sorted { lhs, rhs in
                if lhs.isRunning != rhs.isRunning { return !lhs.isRunning }
                return lhs.isRunning ? lhs.startDate < rhs.startDate : lhs.endDate < rhs.endDate
            }
        }
    }

    /// One group's clock: a running rep counting up, or a rest counting down.
    nonisolated struct LaneStatus: Codable, Hashable, Identifiable, Sendable {
        var id: String
        var name: String
        /// e.g. "Next: 300m" while resting, or "Rep 2 · 300m" while running.
        var detail: String
        var colorIndex: Int
        var isRunning: Bool
        var startDate: Date
        /// When the rest ends. Unused while running.
        var endDate: Date
        /// Seconds left when the coach paused the rest. The clock holds still while this is set.
        var pausedRemaining: TimeInterval? = nil
    }

    var workoutTitle: String
}

#if canImport(ActivityKit)
extension TrackBoardActivityAttributes: ActivityAttributes {}
#endif

/// The color for each group's card, rest bar, and lock-screen row, by its place on the board.
nonisolated enum LaneColor {
    static let colors: [Color] = [
        Color(hex: 0x0064A4),  // UCI blue
        Color(hex: 0xB83A25),  // track red
        Color(hex: 0x2E7D4F),  // infield green
        Color(red: 0.55, green: 0.32, blue: 0.70),  // purple
        Color(red: 0.05, green: 0.55, blue: 0.60),  // teal
        Color(red: 0.62, green: 0.42, blue: 0.20),  // bronze
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }

    /// Rest is over: send this group.
    static let call = Theme.call
    static let rest = Theme.rest
}
