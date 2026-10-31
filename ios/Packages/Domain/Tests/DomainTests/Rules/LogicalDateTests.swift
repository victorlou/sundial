import Testing
@testable import Domain

/// Domain model §4: pure Gregorian arithmetic, no time zones.
@Suite("§4 Logical dates")
struct LogicalDateTests {
    @Test("Components round-trip and weekdays match the calendar")
    func components() {
        let mon = LogicalDate(year: 2026, month: 9, day: 28)
        #expect(mon.year == 2026 && mon.month == 9 && mon.day == 28)
        #expect(mon.weekday == .monday)
        #expect(LogicalDate(year: 1970, month: 1, day: 1).dayNumber == 0)
        #expect(LogicalDate(year: 1970, month: 1, day: 1).weekday == .thursday)
        #expect(LogicalDate(year: 2026, month: 10, day: 4).weekday == .sunday)
        #expect(LogicalDate(year: 1969, month: 12, day: 31).dayNumber == -1)
    }

    @Test("Day arithmetic crosses months and years")
    func dayArithmetic() {
        #expect(Day.wed + 1 == Day.thu)
        #expect(Day.thu - 1 == Day.wed)
        #expect(Day.thu - Day.mon == 3)
        #expect(LogicalDate(year: 2026, month: 12, day: 31) + 1 == LogicalDate(year: 2027, month: 1, day: 1))
        #expect(LogicalDate(year: 2028, month: 2, day: 28) + 1 == LogicalDate(year: 2028, month: 2, day: 29))
        #expect(LogicalDate(year: 2100, month: 2, day: 28) + 1 == LogicalDate(year: 2100, month: 3, day: 1))
    }

    @Test("Adding months clamps to the month's length (DM-06)")
    func addingMonths() {
        let jan31 = LogicalDate(year: 2026, month: 1, day: 31)
        #expect(jan31.adding(months: 1) == LogicalDate(year: 2026, month: 2, day: 28))
        #expect(LogicalDate(year: 2028, month: 1, day: 31).adding(months: 1) == LogicalDate(year: 2028, month: 2, day: 29))
        #expect(jan31.adding(months: 3) == LogicalDate(year: 2026, month: 4, day: 30))
        #expect(jan31.adding(months: 12) == LogicalDate(year: 2027, month: 1, day: 31))
        #expect(LogicalDate(year: 2026, month: 11, day: 15).adding(months: 2) == LogicalDate(year: 2027, month: 1, day: 15))
    }

    @Test("ISO text round-trips, and invalid dates are rejected")
    func isoText() {
        #expect(Day.mon.description == "2026-09-28")
        #expect(LogicalDate("2026-09-28") == Day.mon)
        #expect(LogicalDate("2026-02-30") == nil)
        #expect(LogicalDate("2026-9-28") == nil)
        #expect(LogicalDate(validatingYear: 2026, month: 13, day: 1) == nil)
    }

    @Test("The logical date: before the day start it's the previous date, and it never goes backwards (DM-20)")
    func dayBoundary() {
        let rule = { (wall: LogicalDate, minutes: Int, latest: LogicalDate?) in
            DayBoundaryRule.logicalDate(wallDate: wall, minutesSinceMidnight: minutes, dayStartMinutes: 300, latestUsed: latest)
        }
        #expect(rule(Day.tue, 299, nil) == Day.mon)
        #expect(rule(Day.tue, 300, nil) == Day.tue)
        #expect(rule(Day.tue, 0, nil) == Day.mon)
        #expect(rule(Day.mon, 23 * 60 + 59, nil) == Day.mon)
        #expect(rule(Day.mon, 600, Day.wed) == Day.wed)
    }
}
