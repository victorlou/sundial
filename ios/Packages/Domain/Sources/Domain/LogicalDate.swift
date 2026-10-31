/// A calendar date with no time and no time zone: the day an action counts for (domain model §4).
/// All arithmetic is pure Gregorian arithmetic.
public struct LogicalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Days since 1970-01-01.
    public let dayNumber: Int

    public init(dayNumber: Int) {
        self.dayNumber = dayNumber
    }

    /// Traps on an invalid date. Use `init?(validatingYear:month:day:)` for input that might be invalid.
    public init(year: Int, month: Int, day: Int) {
        guard let date = LogicalDate(validatingYear: year, month: month, day: day) else {
            preconditionFailure("Invalid date \(year)-\(month)-\(day)")
        }
        self = date
    }

    public init?(validatingYear year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...LogicalDate.daysInMonth(year: year, month: month)).contains(day) else { return nil }
        dayNumber = Self.dayNumber(year: year, month: month, day: day)
    }

    /// Parses `YYYY-MM-DD`.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(validatingYear: year, month: month, day: day)
    }

    public var year: Int { components.year }
    public var month: Int { components.month }
    public var day: Int { components.day }

    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        let index = ((dayNumber + 4) % 7 + 7) % 7 // 0 = Sunday
        return Weekday(rawValue: index + 1)!
    }

    /// The Sunday that starts this date's week. Weeks run Sunday to Saturday (§5.1).
    public var startOfWeek: LogicalDate {
        self - (weekday.rawValue - Weekday.sunday.rawValue)
    }

    public func adding(days: Int) -> LogicalDate {
        LogicalDate(dayNumber: dayNumber + days)
    }

    /// Adds calendar months, clamping the day to the new month's length (DM-06).
    public func adding(months: Int) -> LogicalDate {
        let (year, month, day) = components
        let index = year * 12 + (month - 1) + months
        let newYear = index >= 0 ? index / 12 : (index - 11) / 12
        let newMonth = index - newYear * 12 + 1
        return LogicalDate(year: newYear, month: newMonth, day: min(day, Self.daysInMonth(year: newYear, month: newMonth)))
    }

    /// Whole calendar months from `other`'s month to this date's month.
    public func months(since other: LogicalDate) -> Int {
        (year - other.year) * 12 + (month - other.month)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public var description: String {
        let (year, month, day) = components
        func pad(_ value: Int, _ width: Int) -> String {
            let text = String(value)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public static func < (lhs: LogicalDate, rhs: LogicalDate) -> Bool { lhs.dayNumber < rhs.dayNumber }
    public static func + (lhs: LogicalDate, days: Int) -> LogicalDate { lhs.adding(days: days) }
    public static func - (lhs: LogicalDate, days: Int) -> LogicalDate { lhs.adding(days: -days) }
    /// The number of days from `rhs` to `lhs`.
    public static func - (lhs: LogicalDate, rhs: LogicalDate) -> Int { lhs.dayNumber - rhs.dayNumber }

    // Howard Hinnant's civil-date algorithms (proleptic Gregorian calendar).

    private static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private var components: (year: Int, month: Int, day: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }
}

/// Raw values match Foundation's `Calendar` weekday numbers (Sunday = 1).
public enum Weekday: Int, CaseIterable, Hashable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

/// The rule in domain model §4. `DayBoundary` (in Data) reads the clock and the time zone, then calls this.
public enum DayBoundaryRule {
    /// - Parameters:
    ///   - wallDate: today's date on the wall clock, in the device's current time zone.
    ///   - minutesSinceMidnight: the wall-clock time of day.
    ///   - dayStartMinutes: the profile's day start (default 300, 05:00).
    ///   - latestUsed: the latest logical date this device has used for the profile. The result is never earlier (DM-20).
    public static func logicalDate(
        wallDate: LogicalDate, minutesSinceMidnight: Int, dayStartMinutes: Int, latestUsed: LogicalDate?
    ) -> LogicalDate {
        let byRule = minutesSinceMidnight >= dayStartMinutes ? wallDate : wallDate - 1
        guard let latestUsed else { return byRule }
        return max(byRule, latestUsed)
    }
}
