import SwiftUI
import SwiftData

/// The coach's home: create, reorder, and delete event groups, and assign athletes to them.
struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EventGroup.order) private var groups: [EventGroup]
    @Query(sort: \Athlete.name) private var athletes: [Athlete]

    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var groupToDelete: EventGroup?
    @Environment(AuthModel.self) private var auth
    @State private var isCreatingTeam = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groups) { group in
                        NavigationLink(value: group) {
                            EventGroupRow(group: group, athleteCount: athleteCount(in: group))
                        }
                    }
                    .onMove(perform: moveGroups)
                    .onDelete { offsets in
                        groupToDelete = offsets.first.map { groups[$0] }
                    }

                    Button("Add Event Group", systemImage: "plus") {
                        newGroupName = ""
                        isAddingGroup = true
                    }
                } header: {
                    Text("Event Groups")
                } footer: {
                    Text("Each group gets its own sets, goal times, start times, and notes. Athletes only see their own group's plan.")
                }

                Section("Roster") {
                    ForEach(athletes) { athlete in
                        NavigationLink {
                            AthleteAssignmentView(athlete: athlete)
                        } label: {
                            LabeledContent(
                                athlete.name.isEmpty ? "Unnamed Athlete" : athlete.name,
                                value: TrainingGroup.name(for: athlete.eventGroupID, eventGroupNames: groupNames)
                            )
                        }
                    }
                }

                Section {
                    if let team = auth.team {
                        LabeledContent("Team", value: team.name)
                        LabeledContent("Join Code") {
                            Text(team.joinCode)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .textSelection(.enabled)
                        }
                        ShareLink(
                            "Share Join Code",
                            item: "Join \(team.name) on TracKing with code \(team.joinCode)"
                        )
                    } else {
                        Button("Create a Team", systemImage: "person.3.fill") {
                            isCreatingTeam = true
                        }
                    }
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        auth.signOut()
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if auth.team != nil {
                        Text("Athletes enter this code when they set up their account.")
                    }
                }
            }
            .navigationTitle("Team")
            .sheet(isPresented: $isCreatingTeam) {
                TeamSetupView { isCreatingTeam = false }
            }
            .navigationDestination(for: EventGroup.self) { group in
                EventGroupDetailView(group: group)
            }
            .toolbar {
                EditButton()
            }
            .alert("New Event Group", isPresented: $isAddingGroup) {
                TextField("Name", text: $newGroupName)
                Button("Add", action: addGroup)
                    .disabled(trimmedNewName.isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("For example, \"Jumps\" or \"Mid Distance\".")
            }
            .confirmationDialog(
                "Delete \(groupToDelete?.name ?? "Group")?",
                isPresented: Binding(
                    get: { groupToDelete != nil },
                    set: { if !$0 { groupToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: groupToDelete
            ) { group in
                Button("Delete Group", role: .destructive) {
                    EventGroup.delete(group, in: modelContext)
                    groupToDelete = nil
                }
            } message: { group in
                Text("This removes every set, start time, and note written for \(group.name). Athletes in the group will be unassigned.")
            }
        }
    }

    private var trimmedNewName: String {
        newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupNames: [String: String] {
        Dictionary(groups.map { ($0.groupID, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func athleteCount(in group: EventGroup) -> Int {
        athletes.count { $0.eventGroupID == group.groupID }
    }

    private func addGroup() {
        guard !trimmedNewName.isEmpty else { return }
        let nextOrder = (groups.map(\.order).max() ?? -1) + 1
        modelContext.insert(EventGroup(name: trimmedNewName, order: nextOrder))
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.order = index
        }
    }
}

private struct EventGroupRow: View {
    let group: EventGroup
    let athleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.name)
                .fontWeight(.medium)
            Text(athleteCount == 1 ? "1 athlete" : "\(athleteCount) athletes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Where the coach assigns an athlete's event group and gender group.
struct AthleteAssignmentView: View {
    @Bindable var athlete: Athlete

    @Query(sort: \EventGroup.order) private var groups: [EventGroup]

    var body: some View {
        Form {
            Section {
                Picker("Event Group", selection: $athlete.eventGroupID) {
                    Text("Unassigned").tag("")
                    ForEach(groups) { group in
                        Text(group.name).tag(group.groupID)
                    }
                }
                Picker("Men or Women", selection: $athlete.genderGroupID) {
                    ForEach(TrainingGroup.genderGroups) { group in
                        Text(group.name).tag(group.id)
                    }
                }
            } footer: {
                Text("The event group decides which sets the athlete sees. Men's and women's goal times are picked from the group.")
            }
        }
        .navigationTitle(athlete.name.isEmpty ? "Athlete" : athlete.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CoachView()
        .environment(AuthModel())
        .modelContainer(SampleData.previewContainer)
}
