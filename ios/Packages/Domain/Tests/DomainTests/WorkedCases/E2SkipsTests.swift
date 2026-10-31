import Testing
@testable import Domain

/// Domain model §7, E2 — Skips (and the snooze row).
@Suite("E2 Skips")
struct E2SkipsTests {
    static let flossVersion = version(
        "floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed
    )

    static func floss(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(task: personalTask("floss", "Floss"), versions: [flossVersion], actions: actions)
    }

    static func tick(_ day: LogicalDate) -> OccurrenceAction {
        act(.complete, "floss", slot: SlotFixture.evening, occurrence: day)
    }

    @Test("Skip today's floss: resolved, and the streak neither breaks nor grows")
    func skipTodaysFloss() throws {
        let skipped = Self.floss([Self.tick(Day.mon), Self.tick(Day.tue), act(.skip, "floss", slot: SlotFixture.evening, occurrence: Day.wed)])
        let item = try #require(
            TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [skipped], slots: SlotFixture.all).items(for: "floss").first
        )
        #expect(item.resolution == .skipped)
        #expect(RecurrenceEngine(record: skipped, today: Day.wed).streak(for: .profile(Person.bob)) == 2)

        // Doesn't break it either: on Thu, Wed is neutral and Mon–Tue still count.
        #expect(RecurrenceEngine(record: skipped, today: Day.thu).streak(for: .profile(Person.bob)) == 2)

        // For comparison, ticking Wed grows it.
        let ticked = Self.floss([Self.tick(Day.mon), Self.tick(Day.tue), Self.tick(Day.wed)])
        #expect(RecurrenceEngine(record: ticked, today: Day.wed).streak(for: .profile(Person.bob)) == 3)
    }

    @Test("Skip the carried plants item on Wed: resolves Mon and everything before it")
    func skipCarriedPlants() throws {
        // Started the week before, so Thu 09-24 and Mon 09-28 are both in the backlog.
        let plants = TaskRecord(
            task: personalTask("plants", "Water plants"),
            versions: [version("plants", from: Day.prevMon, .weeks(every: 1, on: [.monday, .thursday], start: Day.prevMon),
                               slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: [
                act(.complete, "plants", slot: SlotFixture.anytime, occurrence: Day.prevMon),
                act(.skip, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed),
            ]
        )
        let engine = RecurrenceEngine(record: plants, today: Day.wed)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.anytime)
        #expect(engine.status(of: lane, on: Day.prevMon + 3) == .clearedByLater)
        #expect(engine.status(of: lane, on: Day.mon) == .skipped)

        // Shown checked (skipped) on Wed, because it was acted on today.
        let wed = try #require(TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [plants], slots: SlotFixture.all).items(for: "plants").first)
        #expect(wed.resolution == .skipped)

        // Thu is the next due date, with no backlog behind it.
        let thu = try #require(TodayBuilder.build(viewer: Person.bob, date: Day.thu, tasks: [plants], slots: SlotFixture.all).items(for: "plants").first)
        #expect(thu.resolution == .open)
        #expect(thu.overdueSince == Day.thu)
        #expect(thu.daysOverdue == 0)
    }

    static func sheets(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("sheets", "Change sheets"),
            versions: [version("sheets", from: Day.prevMon, anchor: .floating, .days(every: 7, start: Day.prevMon),
                               slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon)],
            // Last done the previous Mon, so they're due Mon.
            actions: [act(.complete, "sheets", slot: SlotFixture.anytime, occurrence: Day.prevMon)] + actions
        )
    }

    @Test("Skip the floating sheets (due Mon) on Wed: the clock restarts from Wed")
    func skipFloatingSheets() throws {
        let skipped = Self.sheets([act(.skip, "sheets", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed)])
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)

        #expect(RecurrenceEngine(record: skipped, today: Day.wed).state(of: lane)?.resolution == .skipped)
        #expect(RecurrenceEngine(record: skipped, today: Day.thu).state(of: lane) == nil)
        #expect(RecurrenceEngine(record: skipped, today: Day.nextTue).state(of: lane) == nil)

        let next = try #require(RecurrenceEngine(record: skipped, today: Day.nextWed).state(of: lane))
        #expect(next.resolution == .open)
        #expect(next.occurrenceDate == Day.nextWed)
        #expect(next.daysOverdue == 0)
    }

    @Test("Snooze the sheets 3 days on Wed: hidden Thu and Fri, back on Sat with daysOverdue 5")
    func snoozeSheets() throws {
        let snoozed = Self.sheets([
            act(.snooze, "sheets", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed, snoozeUntil: Day.wed + 3),
        ])
        func today(_ date: LogicalDate) -> [TodayItem] {
            TodayBuilder.build(viewer: Person.bob, date: date, tasks: [snoozed], slots: SlotFixture.all).items(for: "sheets")
        }
        #expect(today(Day.wed).isEmpty)
        #expect(today(Day.thu).isEmpty)
        #expect(today(Day.fri).isEmpty)

        let sat = try #require(today(Day.sat).first)
        #expect(sat.resolution == .open)
        #expect(sat.daysOverdue == 5)

        // The count kept running while it was hidden.
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        let fri = try #require(RecurrenceEngine(record: snoozed, today: Day.fri).state(of: lane))
        #expect(fri.isSnoozed)
        #expect(fri.daysOverdue == 4)
    }
}
