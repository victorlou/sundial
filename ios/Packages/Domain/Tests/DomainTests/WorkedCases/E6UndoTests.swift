import Testing
@testable import Domain

/// Domain model §7, E6 — Undo. Today is Wed.
@Suite("E6 Undo")
struct E6UndoTests {
    static let flossVersion = version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed)

    static func floss(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(task: personalTask("floss", "Floss"), versions: [flossVersion], actions: actions)
    }

    @Test("Untick today's floss: the action is revoked and the item is open again")
    func untickFloss() {
        let ticked = Self.floss([act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed)])
        let unticked = Self.floss([act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed, revoked: true)])
        let today = { (record: TaskRecord) in
            TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [record], slots: SlotFixture.all).items(for: "floss").map(\.resolution)
        }
        #expect(today(ticked) == [.done])
        #expect(today(unticked) == [.open])
    }

    @Test("Untick the floating sheets: lastResolution falls back to the previous completion, overdue with the right count")
    func untickSheets() throws {
        let sheets = { (revoked: Bool) in
            TaskRecord(
                task: personalTask("sheets", "Change sheets"),
                versions: [version("sheets", from: Day.prevMon - 7, anchor: .floating, .days(every: 7, start: Day.prevMon - 7),
                                   slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon - 7)],
                actions: [
                    act(.complete, "sheets", slot: SlotFixture.anytime, occurrence: Day.prevMon),
                    act(.complete, "sheets", slot: SlotFixture.anytime, occurrence: Day.mon, revoked: revoked),
                ]
            )
        }
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        #expect(RecurrenceEngine(record: sheets(false), today: Day.wed).state(of: lane) == nil)

        let state = try #require(RecurrenceEngine(record: sheets(true), today: Day.wed).state(of: lane))
        #expect(state.resolution == .open)
        #expect(state.occurrenceDate == Day.mon)
        #expect(state.daysOverdue == 2)
    }

    @Test("Untick the carried plants item that cleared the backlog: the whole backlog reopens, overdue since Mon")
    func untickCarriedPlants() throws {
        let plants = TaskRecord(
            task: personalTask("plants", "Water plants"),
            versions: [version("plants", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon),
                               slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: [act(.complete, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed, revoked: true)]
        )
        let item = try #require(TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [plants], slots: SlotFixture.all).items(for: "plants").first)
        #expect(item.resolution == .open)
        #expect(item.overdueSince == Day.mon)
        #expect(item.daysOverdue == 2)
    }

    @Test("\"I flossed yesterday but forgot to tick\": a backfill for Tue repairs the streak")
    func backfill() {
        let monday = act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.mon)
        let engine = RecurrenceEngine(record: Self.floss([monday]), today: Day.wed)
        #expect(engine.streak(for: .profile(Person.bob)) == 0)

        let tuesday = act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.tue, actedOn: Day.tue)
        #expect(engine.validate(tuesday).isEmpty)
        #expect(RecurrenceEngine(record: Self.floss([monday, tuesday]), today: Day.wed).streak(for: .profile(Person.bob)) == 2)

        // The window is 7 days (DM-07).
        let tooOld = act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed - 8)
        #expect(engine.validate(tooOld).contains(.outsideBackfillWindow))
    }
}
