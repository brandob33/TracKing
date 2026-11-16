import SwiftUI
import SwiftData

/// The athlete's profile: name, training group, personal records, and logging activity.
struct ProfileView: View {
    @Bindable var athlete: Athlete

    @Query private var results: [RepResult]
    @Environment(\.eventGroupNames) private var eventGroupNames
    @State private var isAddingRecord = false

    /// Records in event order, so the list reads 60m, 100m, 200m, and so on.
    private var sortedRecords: [PersonalRecord] {
        athlete.personalRecords.sorted {
            (PersonalRecord.events.firstIndex(of: $0.event) ?? .max) < (PersonalRecord.events.firstIndex(of: $1.event) ?? .max)
        }
    }

    /// Only this athlete's times, not ones the coach logged for teammates.
    private var myResults: [RepResult] {
        results.filter { $0.athleteID == athlete.athleteID }
    }

    private var loggedSessionCount: Int {
        Set(myResults.compactMap { $0.set?.unit?.workout?.persistentModelID }).count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProfileHeader(athlete: athlete)
                }

                Section("Athlete") {
                    TextField("Name", text: $athlete.name)
                        .textContentType(.name)
                }

                Section {
                    LabeledContent("Group", value: TrainingGroup.name(for: athlete.genderGroupID))
                    LabeledContent("Event Group", value: TrainingGroup.name(for: athlete.eventGroupID, eventGroupNames: eventGroupNames))
                } header: {
                    Text("Training Group")
                } footer: {
                    Text("Assigned by your coach. Your group decides which sets, goal times, and start times you see.")
                }

                Section("Personal Records") {
                    ForEach(sortedRecords) { record in
                        HStack {
                            Text(record.event)
                                .fontWeight(.medium)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(TimeFormatting.raceTime(record.seconds, fractionDigits: 2))
                                    .monospacedDigit()
                                Text(record.date, format: .dateTime.month(.abbreviated).day().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { sortedRecords[$0].id }
                        athlete.personalRecords.removeAll { ids.contains($0.id) }
                    }

                    Button("Add Personal Record", systemImage: "plus") {
                        isAddingRecord = true
                    }
                }

                Section("Activity") {
                    LabeledContent("Sessions Logged", value: loggedSessionCount, format: .number)
                    LabeledContent("Reps Logged", value: myResults.count, format: .number)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $isAddingRecord) {
                AddRecordView { record in
                    // Replace any existing record for the same event.
                    athlete.personalRecords.removeAll { $0.event == record.event }
                    athlete.personalRecords.append(record)
                }
            }
        }
    }
}

private struct ProfileHeader: View {
    let athlete: Athlete

    @Environment(\.eventGroupNames) private var eventGroupNames

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                if athlete.initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.title)
                } else {
                    Text(athlete.initials)
                        .font(.title2.bold())
                }
            }
            .foregroundStyle(.tint)
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(athlete.name.isEmpty ? "Your Name" : athlete.name)
                    .font(.title3.bold())
                    .foregroundStyle(athlete.name.isEmpty ? .secondary : .primary)
                Text(athlete.groupSummary(eventGroupNames: eventGroupNames))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A sheet for entering a new personal record.
private struct AddRecordView: View {
    let onSave: (PersonalRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var event = PersonalRecord.events[1]
    @State private var timeText = ""
    @State private var date = Date.now

    private var seconds: Double? {
        TimeFormatting.parse(timeText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Event", selection: $event) {
                    ForEach(PersonalRecord.events, id: \.self) { event in
                        Text(event).tag(event)
                    }
                }
                TextField("Time", text: $timeText, prompt: Text("e.g. 10.85 or 1:52.4"))
                    .keyboardType(.numbersAndPunctuation)
                    .monospacedDigit()
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("New Personal Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let seconds {
                            onSave(PersonalRecord(event: event, seconds: seconds, date: date))
                        }
                        dismiss()
                    }
                    .disabled(seconds == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let container = SampleData.previewContainer
    let athlete = Athlete(name: "Jordan Smith")
    athlete.personalRecords = [
        PersonalRecord(event: "100m", seconds: 10.85, date: .now),
        PersonalRecord(event: "200m", seconds: 21.9, date: .now),
    ]
    container.mainContext.insert(athlete)
    return ProfileView(athlete: athlete)
        .modelContainer(container)
}
