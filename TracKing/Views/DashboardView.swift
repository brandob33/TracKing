import SwiftUI
import SwiftData

/// The athlete's home: the picked day's workout first (today by default) with a Start button,
/// a week of days to move between, and that week's plan info. The ••• on the week strip
/// opens a full month calendar.
struct DashboardView: View {
    @Query(sort: \Workout.date) private var workouts: [Workout]
    @Query(sort: \TrainingWeek.startDate) private var weeks: [TrainingWeek]
    @Environment(\.athleteProfile) private var profile
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

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greeting

                    WeekStrip(selectedDate: $selectedDate, workoutDays: workoutDays)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(Color.cardBackground, in: .rect(cornerRadius: 20))

                    selectedDaySection

                    if let selectedWeek {
                        WeekCard(week: selectedWeek)
                    }
                }
                .padding()
            }
            .background(Color.screenBackground)
            .navigationTitle(isToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") {
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .disabled(isToday)
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                AthleteWorkoutView(workout: workout)
            }
        }
    }

    private var greeting: some View {
        HStack(spacing: 12) {
            LogoMark(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(firstName.isEmpty ? "Your Training" : "Hi, \(firstName)")
                    .font(.title2.bold())
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? ""
    }

    @ViewBuilder
    private var selectedDaySection: some View {
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

/// A session on the athlete's home: its start time, numbered units, how much is logged, and
/// a Start button. The whole card opens the workout.
struct WorkoutCard: View {
    let workout: Workout

    @Environment(\.athleteProfile) private var profile

    var body: some View {
        let totalReps = workout.visibleSets(for: profile).reduce(0) { $0 + $1.totalReps }
        let loggedReps = workout.loggedRepCount(for: profile)
        let isDone = totalReps > 0 && loggedReps >= totalReps
        let action = totalReps == 0 ? "Open" : isDone ? "Review" : loggedReps == 0 ? "Start" : "Continue"

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session \(workout.sessionNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.15), in: .capsule)
                if let focus = workout.week?.focus, !focus.isEmpty {
                    FocusBadge(text: focus)
                }
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
            }

            Text(workout.title)
                .font(.title2.bold())

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

            if totalReps > 0 {
                ProgressView(value: Double(min(loggedReps, totalReps)), total: Double(totalReps))
                    .tint(isDone ? Theme.go : Theme.blue)
            }

            HStack {
                if totalReps > 0 {
                    Text(isDone ? "All \(totalReps) reps logged" : "\(loggedReps) of \(totalReps) reps logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(action, systemImage: isDone ? "checkmark" : "play.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isDone ? Theme.finishFill : Theme.goFill, in: .capsule)
            }
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
