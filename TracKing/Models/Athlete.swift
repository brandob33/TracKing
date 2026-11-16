import Foundation
import SwiftData

/// An athlete on the team. One of them is the person using this device (`isDeviceUser`);
/// the rest make up the coach's roster until sign-in brings in real accounts.
@Model
final class Athlete {
    /// Stable ID that logged times refer to. Will become the Firebase user ID.
    var athleteID: String = UUID().uuidString
    /// Whether this is the athlete using this device.
    var isDeviceUser: Bool = false
    var name: String
    /// Gender group, e.g. "men" or "women". Coaches will assign this later.
    var genderGroupID: String
    /// Event group, e.g. "shortSprint". Coaches will assign this later.
    var eventGroupID: String
    var personalRecords: [PersonalRecord] = []

    init(
        name: String = "",
        genderGroupID: String = TrainingGroup.men.id,
        eventGroupID: String = TrainingGroup.shortSprint.id,
        isDeviceUser: Bool = false
    ) {
        self.isDeviceUser = isDeviceUser
        self.name = name
        self.genderGroupID = genderGroupID
        self.eventGroupID = eventGroupID
    }

    /// The groups this athlete belongs to, most specific first, for filtering workouts.
    var profile: AthleteProfile {
        var groupIDs = [eventGroupID, genderGroupID]
        // Coach notes aimed at one athlete use their first name, e.g. "SARA".
        if let firstName = name.split(separator: " ").first {
            groupIDs.insert(TrainingGroup.athlete(String(firstName)).id, at: 0)
        }
        return AthleteProfile(name: name, groupIDs: groupIDs, athleteID: athleteID)
    }

    /// e.g. "Short Sprints · Men"
    func groupSummary(eventGroupNames: [String: String]) -> String {
        [eventGroupID, genderGroupID]
            .map { TrainingGroup.name(for: $0, eventGroupNames: eventGroupNames) }
            .joined(separator: " · ")
    }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// A personal best in one event.
struct PersonalRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    var event: String
    var seconds: Double
    var date: Date
}

extension TrainingGroup {
    static let genderGroups: [TrainingGroup] = [.men, .women]
}

extension PersonalRecord {
    /// Events offered when adding a personal record, in display order.
    static let events = ["60m", "100m", "200m", "300m", "400m", "60mH", "100mH", "110mH", "400mH"]
}
