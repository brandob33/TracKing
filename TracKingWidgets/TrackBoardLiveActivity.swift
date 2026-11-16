import ActivityKit
import SwiftUI
import WidgetKit

/// Rest countdowns (and running reps) on the lock screen and in the Dynamic Island, so the
/// coach can see when each group is due back on the line without opening the app.
struct TrackBoardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackBoardActivityAttributes.self) { context in
            LockScreenView(title: context.attributes.workoutTitle, lanes: context.state.sortedLanes)
                .activityBackgroundTint(Theme.midnight.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let lanes = context.state.sortedLanes
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ForEach(lanes.prefix(3)) { lane in
                            LaneRow(lane: lane)
                        }
                    }
                }
            } compactLeading: {
                if let lane = lanes.first {
                    HStack(spacing: 4) {
                        Image(systemName: lane.isRunning ? "stopwatch" : "timer")
                        Text(lane.name)
                            .lineLimit(1)
                            .frame(maxWidth: 70, alignment: .leading)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(lane.isRunning ? Color.white : Theme.restOnDark)
                }
            } compactTrailing: {
                if let lane = lanes.first {
                    LaneClock(lane: lane)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: 48)
                }
            } minimal: {
                if let lane = lanes.first {
                    LaneClock(lane: lane)
                        .font(.caption2.weight(.bold))
                }
            }
        }
    }
}

private struct LockScreenView: View {
    let title: String
    let lanes: [TrackBoardActivityAttributes.LaneStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TracKing · \(title)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            ForEach(lanes.prefix(4)) { lane in
                LaneRow(lane: lane)
            }
        }
        .padding(14)
    }
}

private struct LaneRow: View {
    let lane: TrackBoardActivityAttributes.LaneStatus

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LaneColor.color(lane.colorIndex))
                .frame(width: 24, height: 24)
                .overlay {
                    Text("\(lane.colorIndex + 1)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 0) {
                Text(lane.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(lane.isRunning ? "Running · \(lane.detail)" : lane.detail)
                    .font(.caption)
                    .opacity(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 8)
            LaneClock(lane: lane)
                .font(.title2.weight(.bold))
        }
    }
}

/// Counts down a rest or counts up a running rep, updated by the system without the app running.
private struct LaneClock: View {
    let lane: TrackBoardActivityAttributes.LaneStatus

    var body: some View {
        Group {
            if lane.isRunning {
                Text(timerInterval: lane.startDate...Date.distantFuture, countsDown: false)
                    .foregroundStyle(.white)
            } else if let paused = lane.pausedRemaining {
                Text(Duration.seconds(paused.rounded(.up)).formatted(.time(pattern: .minuteSecond)))
                    .foregroundStyle(Theme.restOnDark.opacity(0.6))
            } else {
                Text(timerInterval: lane.startDate...lane.endDate, countsDown: true)
                    .foregroundStyle(Theme.restOnDark)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}
