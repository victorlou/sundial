import Testing
@testable import Domain

/// Domain model §5.1 — Patterns (fixed due dates), and §5.3 — nothing before the first effectiveFrom.
@Suite("§5.1 Patterns")
struct PatternTests {
    /// The due dates of a one-version, one-lane personal task in [from, through].
    static func dueDates(
        _ pattern: Pattern, from effectiveFrom: LogicalDate, through end: LogicalDate, policy: MissPolicy = .markMissed
    ) -> [LogicalDate] {
        let record = TaskRecord(
            task: personalTask("t", "Task"),
            versions: [version("t", from: effectiveFrom, pattern, slots: [SlotFixture.anytime], policy: policy)],
            actions: []
        )
        let engine = RecurrenceEngine(record: record, today: end)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.anytime)
        return stride(from: effectiveFrom.dayNumber - 40, through: end.dayNumber, by: 1)
            .map(LogicalDate.init(dayNumber:))
            .filter { engine.isDue(lane, on: $0) }
    }

    static func date(_ y: Int, _ m: Int, _ d: Int) -> LogicalDate { LogicalDate(year: y, month: m, day: d) }

    @Test("once with a date: due on that date only")
    func onceDated() {
        #expect(Self.dueDates(.once(date: Day.fri), from: Day.mon, through: Day.nextWed) == [Day.fri])
    }

    @Test("once without a date: due on effectiveFrom")
    func onceUndated() {
        #expect(Self.dueDates(.once(date: nil), from: Day.wed, through: Day.nextWed) == [Day.wed])
    }

    static func passport(_ second: [SlotID], _ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("passport", "Renew passport"),
            versions: [
                version("passport", from: Day.mon, .once(date: nil), slots: [SlotFixture.anytime], policy: .carryOver),
                version("passport", from: Day.thu, .once(date: nil), slots: second, policy: .carryOver),
            ],
            actions: actions
        )
    }

    @Test("Undated once: a later version keeps the lane's due date, so an edit neither reopens it nor resets the count")
    func onceUndatedAcrossVersions() throws {
        let engine = RecurrenceEngine(record: Self.passport([SlotFixture.anytime], []), today: Day.fri)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.anytime)
        #expect(engine.isDue(lane, on: Day.thu) == false)
        #expect(try #require(engine.state(of: lane)).overdueSince == Day.mon)

        // Done on Tue, then edited on Thu: it stays done.
        let done = Self.passport([SlotFixture.anytime], [act(.complete, "passport", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.tue)])
        let after = RecurrenceEngine(record: done, today: Day.fri)
        #expect(after.state(of: after.lane(.profile(Person.bob), SlotFixture.anytime)) == nil)
    }

    @Test("Undated once moved to another slot: like any slot change, a new lane due from the move (§5.2)")
    func onceUndatedMovedSlot() throws {
        let engine = RecurrenceEngine(record: Self.passport([SlotFixture.morning], []), today: Day.fri)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.morning)
        #expect(engine.lanes() == [lane])
        #expect(try #require(engine.state(of: lane)).overdueSince == Day.thu)
    }

    @Test("days every n: start + k·n, nothing before start")
    func everyNDays() {
        #expect(Self.dueDates(.days(every: 3, start: Day.tue), from: Day.mon, through: Day.nextTue)
            == [Day.tue, Day.fri, Day.nextMon])
        // `start` belongs to the pattern: a later effectiveFrom doesn't shift the days.
        #expect(Self.dueDates(.days(every: 3, start: Day.tue), from: Day.wed, through: Day.nextTue)
            == [Day.fri, Day.nextMon])
    }

    @Test("weeks every 2: weeks start on Sunday; the start week counts from start on")
    func everyTwoWeeks() {
        // Start Wed 09-30, Mon/Thu: week 0 is Sun 09-27 to Sat 10-03, so its Mon (before start) is skipped and its Thu is due.
        let dates = Self.dueDates(.weeks(every: 2, on: [.monday, .thursday], start: Day.wed), from: Day.wed, through: Self.date(2026, 10, 31))
        #expect(dates == [Self.date(2026, 10, 1), Self.date(2026, 10, 12), Self.date(2026, 10, 15), Self.date(2026, 10, 26), Self.date(2026, 10, 29)])
    }

    @Test("weeks: a Sunday belongs to the week it starts, not the week before")
    func sundayStartsTheWeek() {
        // Start Sat 10-03, every 2 weeks on Sun: Sun 10-04 starts week 1, so the first due Sunday is 10-11.
        let dates = Self.dueDates(.weeks(every: 2, on: [.sunday], start: Day.sat), from: Day.sat, through: Self.date(2026, 10, 31))
        #expect(dates == [Self.date(2026, 10, 11), Self.date(2026, 10, 25)])
    }

    @Test("months, day k: clamped to the month's length (DM-06)")
    func monthlyDay31() {
        let dates = Self.dueDates(.months(every: 1, on: .day(31), start: Self.date(2026, 1, 1)), from: Self.date(2026, 1, 1), through: Self.date(2026, 5, 31))
        #expect(dates == [Self.date(2026, 1, 31), Self.date(2026, 2, 28), Self.date(2026, 3, 31), Self.date(2026, 4, 30), Self.date(2026, 5, 31)])
    }

    @Test("months every 2: counted from start's month, nothing before start")
    func everyTwoMonths() {
        // Start 2026-01-20 on day 15: January's 15th is before start.
        let dates = Self.dueDates(.months(every: 2, on: .day(15), start: Self.date(2026, 1, 20)), from: Self.date(2026, 1, 1), through: Self.date(2026, 7, 31))
        #expect(dates == [Self.date(2026, 3, 15), Self.date(2026, 5, 15), Self.date(2026, 7, 15)])
    }

    @Test("months, nth weekday: the first and the last Saturday")
    func nthWeekday() {
        let start = Self.date(2026, 10, 1)
        #expect(Self.dueDates(.months(every: 1, on: .weekday(.first, .saturday), start: start), from: start, through: Self.date(2026, 12, 31))
            == [Self.date(2026, 10, 3), Self.date(2026, 11, 7), Self.date(2026, 12, 5)])
        #expect(Self.dueDates(.months(every: 1, on: .weekday(.last, .saturday), start: start), from: start, through: Self.date(2026, 12, 31))
            == [Self.date(2026, 10, 31), Self.date(2026, 11, 28), Self.date(2026, 12, 26)])
        #expect(Self.dueDates(.months(every: 1, on: .weekday(.fourth, .thursday), start: start), from: start, through: Self.date(2026, 11, 30))
            == [Self.date(2026, 10, 22), Self.date(2026, 11, 26)])
    }

    @Test("§5.3: due dates exist only from the task's first effectiveFrom")
    func nothingBeforeEffectiveFrom() {
        #expect(Self.dueDates(.days(every: 1, start: Day.prevMon), from: Day.thu, through: Day.sat) == [Day.thu, Day.fri, Day.sat])
    }
}
