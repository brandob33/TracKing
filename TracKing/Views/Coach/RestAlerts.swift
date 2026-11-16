import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Tells the coach when a rest is over even with the phone locked: a notification when each
/// rest ends, and a Live Activity with every running clock on the lock screen and in the
/// Dynamic Island.
final class RestAlerts {
    private var hasAskedPermission = false
    #if canImport(ActivityKit)
    private var activity: Activity<TrackBoardActivityAttributes>?
    #endif

    func requestPermissionIfNeeded() {
        guard !hasAskedPermission else { return }
        hasAskedPermission = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    func scheduleRestEnd(id: String, title: String, at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(title): on the line"
        content.body = "Rest is over."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: notificationID(id),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelRestEnd(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID(id)])
    }

    private func notificationID(_ id: String) -> String {
        "rest.\(id)"
    }

    /// Starts, updates, or (when nothing is running or resting) ends the Live Activity.
    func updateLiveActivity(_ lanes: [TrackBoardActivityAttributes.LaneStatus], workoutTitle: String) {
        #if canImport(ActivityKit)
        let state = TrackBoardActivityAttributes.ContentState(lanes: lanes)
        if lanes.isEmpty {
            if let activity {
                self.activity = nil
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        // Nothing needs updating once every rest and clock has stopped, so no stale date.
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            activity = try? Activity.request(
                attributes: TrackBoardActivityAttributes(workoutTitle: workoutTitle),
                content: content,
                pushType: nil
            )
        }
        #endif
    }
}
