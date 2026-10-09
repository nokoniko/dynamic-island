import Foundation

/// How often the background update check runs.
enum UpdateFrequency: String, CaseIterable, Identifiable {
    case hourly, daily, everyTwoDays, weekly

    var id: Self { self }

    var title: String {
        switch self {
        case .hourly: "Every hour"
        case .daily: "Every day"
        case .everyTwoDays: "Every 2 days"
        case .weekly: "Every week"
        }
    }

    /// Days between checks; `nil` for the hourly check, which ignores the time of day.
    var days: Int? {
        switch self {
        case .hourly: nil
        case .daily: 1
        case .everyTwoDays: 2
        case .weekly: 7
        }
    }
}

/// When during the day a daily (or rarer) check runs.
enum UpdateTimeOfDay: String, CaseIterable, Identifiable {
    case morning, afternoon, evening

    var id: Self { self }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    var hour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .evening: 19
        }
    }
}

enum UpdateSchedule {
    /// When the next background check is due. A date in the past means "now" — e.g.
    /// the Mac was asleep at the chosen time, so it checks as soon as it's awake.
    /// The next slot is counted from the day of the last check, so a late check
    /// doesn't push the following ones later.
    static func nextCheck(after lastCheck: Date?, frequency: UpdateFrequency, timeOfDay: UpdateTimeOfDay,
                          now: Date, calendar: Calendar) -> Date {
        // A last check "in the future" (the clock was changed) counts as now.
        let last = lastCheck.map { min($0, now) }
        guard let days = frequency.days else {
            return last?.addingTimeInterval(60 * 60) ?? now
        }
        let day = calendar.startOfDay(for: last ?? now)
        let target = calendar.date(byAdding: .day, value: last == nil ? 0 : days, to: day) ?? day
        return calendar.date(bySettingHour: timeOfDay.hour, minute: 0, second: 0, of: target) ?? target
    }
}
