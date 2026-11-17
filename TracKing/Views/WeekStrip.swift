import SwiftUI

/// One week of days to pick from, Monday to Sunday, with a dot under each day that has a
/// session. The arrows move a week at a time, and the ••• button opens a full month calendar.
struct WeekStrip: View {
    @Binding var selectedDate: Date
    /// Start-of-day dates that have at least one session.
    let workoutDays: Set<Date>

    @State private var isShowingCalendar = false

    /// Weeks run Monday to Sunday, like the coach's plan.
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var days: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        HStack(spacing: 2) {
            Button("Previous Week", systemImage: "chevron.left") { move(byWeeks: -1) }
                .frame(width: 28, height: 44)
            ForEach(days, id: \.self) { day in
                dayButton(day)
            }
            Button("Next Week", systemImage: "chevron.right") { move(byWeeks: 1) }
                .frame(width: 28, height: 44)
            Button("Month Calendar", systemImage: "ellipsis") { isShowingCalendar = true }
                .frame(width: 30, height: 44)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .sheet(isPresented: $isShowingCalendar) {
            NavigationStack {
                MonthCalendarView(selectedDate: $selectedDate, workoutDays: workoutDays)
                    .padding()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle("Pick a Day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Today") {
                                selectedDate = Calendar.current.startOfDay(for: .now)
                                isShowingCalendar = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingCalendar = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasWorkout = workoutDays.contains(calendar.startOfDay(for: day))

        return Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(isSelected || isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.blue : Color.primary))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Theme.finishFill)
                        } else if isToday {
                            Circle().strokeBorder(Theme.blue, lineWidth: 1.5)
                        }
                    }
                Circle()
                    .fill(hasWorkout ? Theme.blue : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(hasWorkout ? "Has a session" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func move(byWeeks weeks: Int) {
        if let newDate = calendar.date(byAdding: .day, value: weeks * 7, to: selectedDate) {
            selectedDate = calendar.startOfDay(for: newDate)
        }
    }
}

/// The TracKing mark, for headers and the opening screen.
struct LogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        Image("LogoMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var selectedDate = Calendar.current.startOfDay(for: .now)
    WeekStrip(selectedDate: $selectedDate, workoutDays: [selectedDate])
        .padding()
}
