import SwiftUI
import SwiftData

/// Home screen: the selected day's workout (today by default), that week's plan info, and a calendar for picking a day.
struct DashboardView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \TrainingWeek.startDate) private var weeks: [TrainingWeek]
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    private var workoutDays: Set<Date> {
        Set(workouts.map { calendar.startOfDay(for: $0.date) })
    }

    private var selectedDayWorkouts: [Workout] {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedWeek: TrainingWeek? {
        weeks.first { $0.contains(selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectedDaySection

                    if let selectedWeek {
                        WeekCard(week: selectedWeek)
                    }

                    MonthCalendarView(selectedDate: $selectedDate, workoutDays: workoutDays)
                        .padding()
                        .background(Color.cardBackground, in: .rect(cornerRadius: 20))
                }
                .padding()
            }
            .background(Color.screenBackground)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") {
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .disabled(calendar.isDateInToday(selectedDate))
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        Group {
            if calendar.isDateInToday(selectedDate) {
                Text("Today's Workout")
            } else {
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
            }
        }
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

        if selectedDayWorkouts.isEmpty {
            ContentUnavailableView(
                "Rest Day",
                systemImage: "bed.double.fill",
                description: Text("No workout is scheduled for this day.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .background(Color.cardBackground, in: .rect(cornerRadius: 20))
        } else {
            ForEach(selectedDayWorkouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutCard(workout: workout)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Summary of a session shown on the dashboard: its start time and numbered units.
struct WorkoutCard: View {
    let workout: Workout

    @Environment(\.athleteProfile) private var profile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session \(workout.sessionNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.15), in: .capsule)
                Spacer()
                if let startTime = workout.startTime(for: profile) {
                    Label {
                        Text(startTime, format: .dateTime.hour().minute())
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            Text(workout.title)
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                ForEach(workout.orderedUnits) { unit in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: unit.kind.systemImage)
                            .foregroundStyle(.tint)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unit.title)
                                .fontWeight(.medium)
                            let sets = unit.orderedSets.filter { profile.canSee($0.groupID) }
                            if !sets.isEmpty {
                                Text(sets.map(\.repsAndDistance).joined(separator: ", "))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.cardBackground, in: .rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
    }
}

/// The week's plan info from the top of the coach's sheet, plus coach contact.
struct WeekCard: View {
    let week: TrainingWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(week.teamName)
                    .font(.headline)
                Spacer()
                if !week.focus.isEmpty {
                    FocusBadge(text: week.focus)
                }
            }
            Text(week.cycleSummary)
                .font(.subheadline)
            Text("Week of \(week.startDate.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !week.notes.isEmpty {
                Text(week.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: .rect(cornerRadius: 20))
    }
}

extension Color {
    static let screenBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
}

#Preview {
    DashboardView()
        .modelContainer(SampleData.previewContainer)
}
