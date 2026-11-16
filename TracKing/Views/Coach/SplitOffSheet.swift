import SwiftUI

/// Picks athletes to time apart from their group for this session, e.g. two sprinters
/// practicing at a different time. They get their own card on the board for the day.
struct SplitOffSheet: View {
    let session: GroupSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.eventGroupNames) private var eventGroupNames
    @State private var selection: Set<String> = []

    private var selected: [Athlete] {
        session.athletes.filter { selection.contains($0.athleteID) }
    }

    var body: some View {
        NavigationStack {
            List(session.athletes, id: \.athleteID, selection: $selection) { athlete in
                Text(athlete.name.isEmpty ? "Unnamed Athlete" : athlete.name)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Time Separately")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text("Pick who's running at a different time. They get their own card for \(session.workout.date.formatted(.dateTime.weekday(.wide))), and their times still count toward this workout, so they can finish it later. \(session.title(eventGroupNames: eventGroupNames)) keeps going without them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Time" : "Time \(selected.count)") {
                        session.workout.splitOff(selected)
                        dismiss()
                    }
                    .disabled(selected.isEmpty || selected.count == session.athletes.count)
                }
            }
        }
    }
}
