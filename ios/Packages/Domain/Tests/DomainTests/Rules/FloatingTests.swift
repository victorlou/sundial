import Testing
@testable import Domain

/// Domain model §5.5 — Floating lanes.
@Suite("§5.5 Floating lanes")
struct FloatingTests {
    static let lane = Lane(taskId: "f", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)

    static func floating(_ pattern: Pattern, from: LogicalDate = Day.prevMon, seed: LogicalDate? = Day.prevMon, _ actions: [OccurrenceAction] = []) -> TaskRecord {
        TaskRecord(
            task: personalTask("f", "Floating"),
            versions: [version("f", from: from, anchor: .floating, pattern, slots: [SlotFixture.anytime], policy: .carryOver, seed: seed)],
            actions: actions
        )
    }

    static func done(_ day: LogicalDate) -> OccurrenceAction {
        act(.complete, "f", slot: SlotFixture.anytime, occurrence: day)
    }

    @Test("With no history, the seed is the first due date")
    func seed() throws {
        let record = Self.floating(.days(every: 7, start: Day.prevMon), seed: Day.tue)
        #expect(RecurrenceEngine(record: record, today: Day.mon).state(of: Self.lane) == nil)
        let wed = try #require(RecurrenceEngine(record: record, today: Day.wed).state(of: Self.lane))
        #expect(wed.occurrenceDate == Day.tue)
        #expect(wed.overdueSince == Day.tue)
        #expect(wed.daysOverdue == 1)
    }

    @Test("nextDue = lastResolution + interval, from the greatest actedOn")
    func nextDue() {
        // Ticked late: the clock restarts from the day it was done, not the occurrence.
        let late = act(.complete, "f", slot: SlotFixture.anytime, occurrence: Day.prevMon, actedOn: Day.mon)
        let record = Self.floating(.days(every: 3, start: Day.prevMon), [late])
        #expect(RecurrenceEngine(record: record, today: Day.wed).state(of: Self.lane) == nil)
        #expect(RecurrenceEngine(record: record, today: Day.thu).state(of: Self.lane)?.occurrenceDate == Day.thu)
    }

    @Test("Floating weeks n: 7n days")
    func floatingWeeks() {
        let record = Self.floating(.weeks(every: 2, on: [], start: Day.prevMon), [Self.done(Day.mon)])
        #expect(RecurrenceEngine(record: record, today: Day.mon + 13).state(of: Self.lane)?.resolution == nil)
        #expect(RecurrenceEngine(record: record, today: Day.mon + 14).state(of: Self.lane)?.resolution == .open)
        #expect(RecurrenceEngine(record: record, today: Day.mon + 14).state(of: Self.lane)?.nominalPeriod == 14)
    }

    @Test("Floating months n: calendar months, clamped (DM-06)")
    func floatingMonths() {
        let jan31 = LogicalDate(year: 2026, month: 1, day: 31)
        let record = Self.floating(.months(every: 1, on: nil, start: jan31), from: jan31, seed: jan31, [Self.done(jan31)])
        let feb27 = LogicalDate(year: 2026, month: 2, day: 27)
        let feb28 = LogicalDate(year: 2026, month: 2, day: 28)
        #expect(RecurrenceEngine(record: record, today: feb27).state(of: Self.lane) == nil)
        #expect(RecurrenceEngine(record: record, today: feb28).state(of: Self.lane)?.occurrenceDate == feb28)
    }

    @Test("Skips restart the clock; snoozes don't (DM-05)")
    func skipsCountSnoozesDont() {
        let skip = act(.skip, "f", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.tue)
        #expect(RecurrenceEngine(record: Self.floating(.days(every: 7, start: Day.prevMon), [skip]), today: Day.wed).state(of: Self.lane) == nil)

        let snooze = act(.snooze, "f", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.tue, snoozeUntil: Day.wed)
        #expect(RecurrenceEngine(record: Self.floating(.days(every: 7, start: Day.prevMon), [snooze]), today: Day.wed).state(of: Self.lane)?.daysOverdue == 9)
    }

    @Test("A completion dated after this device's today never makes daysOverdue negative (DM-20)")
    func futureActedOn() {
        let ahead = act(.complete, "f", slot: SlotFixture.anytime, occurrence: Day.wed, actedOn: Day.wed)
        let state = RecurrenceEngine(record: Self.floating(.days(every: 1, start: Day.prevMon), [ahead]), today: Day.mon).state(of: Self.lane)
        #expect(state == nil || state!.daysOverdue >= 0)
    }
}
