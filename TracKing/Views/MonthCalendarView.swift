import SwiftUI

/// A month grid that lets the user pick a day. Days with a scheduled workout show a dot.
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    /// Start-of-day dates that have at least one workout.
    let workoutDays: Set<Date>

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gridDays) { day in
                    if let date = day.date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            // Keep the visible month in sync when the selection jumps (e.g. "Today").
            let month = calendar.startOfMonth(for: newValue)
            if month != displayedMonth {
                withAnimation { displayedMonth = month }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
            Spacer()
            Button("Previous Month", systemImage: "chevron.left") { changeMonth(by: -1) }
            Button("Next Month", systemImage: "chevron.right") { changeMonth(by: 1) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.title3)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasWorkout = workoutDays.contains(date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text(date, format: .dateTime.day())
                    .font(.body.weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.blue : Color.primary))
                    .frame(width: 34, height: 34)
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
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(hasWorkout ? "Workout scheduled" : "No workout")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func changeMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation { displayedMonth = month }
    }

    /// Weekday abbreviations ordered to match the user's first day of the week.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// The days of the displayed month, padded with empty leading cells so day 1 lands on the right weekday.
    private var gridDays: [CalendarDay] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days = (0..<leadingBlanks).map { CalendarDay(id: -($0 + 1), date: nil) }
        for dayNumber in range {
            let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: displayedMonth)
            days.append(CalendarDay(id: dayNumber, date: date))
        }
        return days
    }
}

private struct CalendarDay: Identifiable {
    let id: Int
    let date: Date?
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

#Preview {
    @Previewable @State var selectedDate = Calendar.current.startOfDay(for: .now)
    MonthCalendarView(selectedDate: $selectedDate, workoutDays: [selectedDate])
        .padding()
}
