import SwiftUI

/// A group that coach instructions can target: a gender group, an event group, or a single athlete.
/// Event groups are created by the coach (see `EventGroup`); these are the built-in IDs and the starting set.
struct TrainingGroup: Hashable, Identifiable {
    let id: String
    let name: String

    static let men = TrainingGroup(id: "men", name: "Men")
    static let women = TrainingGroup(id: "women", name: "Women")
    /// The event groups a new team starts with. The coach can rename, remove, or add to these.
    static let shortSprint = TrainingGroup(id: "shortSprint", name: "Short Sprints")
    static let longSprint = TrainingGroup(id: "longSprint", name: "Long Sprints")
    static let shortHurdles = TrainingGroup(id: "shortHurdles", name: "Short Hurdles")
    static let longHurdles = TrainingGroup(id: "longHurdles", name: "Long Hurdles")

    static let defaultEventGroups: [TrainingGroup] = [.shortSprint, .longSprint, .shortHurdles, .longHurdles]

    /// A group containing a single athlete, for instructions aimed at one person.
    static func athlete(_ name: String) -> TrainingGroup {
        TrainingGroup(id: "athlete.\(name.lowercased())", name: name)
    }

    static let known: [TrainingGroup] = [.men, .women] + defaultEventGroups

    /// A display name for a group ID, e.g. "Short Hurdles" or "Sara".
    /// `eventGroupNames` holds the coach's current names, which win over the built-in ones.
    static func name(for id: String, eventGroupNames: [String: String] = [:]) -> String {
        if id.isEmpty {
            return "Unassigned"
        }
        if let name = eventGroupNames[id] {
            return name
        }
        if let group = known.first(where: { $0.id == id }) {
            return group.name
        }
        if id.hasPrefix("athlete.") {
            return id.dropFirst("athlete.".count).capitalized
        }
        return id.capitalized
    }
}

/// The athlete viewing the app, and the groups they belong to. Views use this to show
/// only the start times, targets, sets, and notes meant for this athlete.
struct AthleteProfile: Equatable {
    var name: String
    /// Group IDs ordered from most to least specific, e.g. ["athlete.sara", "shortHurdles", "women"].
    var groupIDs: [String]
    /// Whose logged times to show and save (`Athlete.athleteID`).
    var athleteID: String = ""

    /// Whether an item aimed at `groupID` should be visible. `nil` means everyone.
    func canSee(_ groupID: String?) -> Bool {
        guard let groupID else { return true }
        return groupIDs.contains(groupID)
    }

    /// Picks the most specific item for this athlete, falling back to the one for everyone.
    func bestMatch<Item>(in items: [Item], groupID: (Item) -> String?) -> Item? {
        for id in groupIDs {
            if let match = items.first(where: { groupID($0) == id }) {
                return match
            }
        }
        return items.first { groupID($0) == nil }
    }

    /// Placeholder until coaches can assign athletes to groups.
    static let sample = AthleteProfile(name: "Athlete", groupIDs: [TrainingGroup.shortSprint.id, TrainingGroup.men.id])
}

extension EnvironmentValues {
    @Entry var athleteProfile: AthleteProfile = .sample
    /// Event group names by ID, from the coach's groups, so views can show "For Short Hurdles".
    @Entry var eventGroupNames: [String: String] = [:]
}
