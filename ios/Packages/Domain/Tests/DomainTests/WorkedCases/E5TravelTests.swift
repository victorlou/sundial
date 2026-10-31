import Testing
@testable import Domain

/// Domain model §7, E5 — Travel and the day boundary. Day start 05:00 unless a row changes it.
@Suite("E5 Travel and the day boundary")
struct E5TravelTests {
    static let dayStart = 5 * 60

    static func logical(_ wall: LogicalDate, _ hour: Int, _ minute: Int = 0, dayStart: Int = dayStart, latest: LogicalDate?) -> LogicalDate {
        DayBoundaryRule.logicalDate(wallDate: wall, minutesSinceMidnight: hour * 60 + minute, dayStartMinutes: dayStart, latestUsed: latest)
    }

    static let flossVersion = version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed)

    static func floss(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(task: personalTask("floss", "Floss"), versions: [flossVersion], actions: actions)
    }

    static let mondayTick = act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.mon)

    @Test("London → Tokyo: Tue passed in transit and is missed; Bob repairs it with a backfill skip")
    func eastToTokyo() throws {
        // Ticked Mon 22:00 in London, lands Wed 08:00 in Tokyo.
        #expect(Self.logical(Day.mon, 22, latest: nil) == Day.mon)
        let today = Self.logical(Day.wed, 8, latest: Day.mon)
        #expect(today == Day.wed)

        let record = Self.floss([Self.mondayTick])
        let engine = RecurrenceEngine(record: record, today: today)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.evening)
        #expect(engine.status(of: lane, on: Day.tue) == .missed)
        #expect(engine.streak(for: .profile(Person.bob)) == 0)

        // markMissed: Tue never appears in Today, only Wed's occurrence does.
        let items = TodayBuilder.build(viewer: Person.bob, date: today, tasks: [record], slots: SlotFixture.all).items(for: "floss")
        #expect(items.map(\.occurrenceDate) == [Day.wed])

        // The repair: a skip for Tue, inside the 7-day backfill window.
        let skipTue = act(.skip, "floss", slot: SlotFixture.evening, occurrence: Day.tue)
        #expect(engine.validate(skipTue).isEmpty)
        let repaired = RecurrenceEngine(record: Self.floss([Self.mondayTick, skipTue]), today: today)
        #expect(repaired.status(of: lane, on: Day.tue) == .skipped)
        #expect(repaired.streak(for: .profile(Person.bob)) == 1)
    }

    @Test("Alice at home sees Bob's household items on her Tuesday, never his personal floss")
    func aliceAtHome() {
        let recycling = TaskRecord(
            task: householdTask("recycling", "Recycling"),
            versions: [version("recycling", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening],
                               policy: .markMissed, assignment: .each([Person.bob]))],
            actions: []
        )
        let floss = Self.floss([Self.mondayTick])

        // Bob's column, computed with the viewer's (Alice's) date: Tue.
        let bobsColumn = TodayBuilder.build(viewer: Person.bob, date: Day.tue, tasks: [floss, recycling], slots: SlotFixture.all, openMembers: Person.everyone)
        #expect(bobsColumn.items(for: "recycling").map(\.resolution) == [.open])

        // Alice's own Today has neither.
        let alices = TodayBuilder.build(viewer: Person.alice, date: Day.tue, tasks: [floss, recycling], slots: SlotFixture.all, openMembers: Person.everyone)
        #expect(alices.allItems.isEmpty)

        // On Wed, Tue resolves by its policy: missed.
        let engine = RecurrenceEngine(record: recycling, today: Day.wed, openMembers: Person.everyone)
        #expect(engine.status(of: engine.lane(.profile(Person.bob), SlotFixture.evening), on: Day.tue) == .missed)
    }

    @Test("London → LA the same Mon: still logical Mon, already resolved, nothing duplicated")
    func westToLA() {
        #expect(Self.logical(Day.mon, 15, latest: nil) == Day.mon)
        let today = Self.logical(Day.mon, 19, latest: Day.mon)
        #expect(today == Day.mon)

        let items = TodayBuilder.build(viewer: Person.bob, date: today, tasks: [Self.floss([Self.mondayTick])], slots: SlotFixture.all).items(for: "floss")
        #expect(items.map(\.resolution) == [.done])
    }

    @Test("Tokyo → LA across the date line: Today stays Wed until 05:00 Thu in LA")
    func dateLine() {
        // Started logical Wed in Tokyo, lands 23:30 Tue in LA.
        #expect(Self.logical(Day.tue, 23, 30, latest: Day.wed) == Day.wed)
        #expect(Self.logical(Day.thu, 4, 59, latest: Day.wed) == Day.wed)
        #expect(Self.logical(Day.thu, 5, 0, latest: Day.wed) == Day.thu)

        // Wed's ticks still show, and nothing from Tue reappears.
        let wedTick = act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed)
        let items = TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [Self.floss([Self.mondayTick, wedTick])], slots: SlotFixture.all).items(for: "floss")
        #expect(items.map(\.occurrenceDate) == [Day.wed])
        #expect(items.map(\.resolution) == [.done])
    }

    @Test("A tick at 04:30 Tue with day start 05:00 counts for Mon")
    func beforeDayStart() {
        #expect(Self.logical(Day.tue, 4, 30, latest: Day.mon) == Day.mon)
    }

    @Test("Day start 05:00 → 02:00 at 03:00: Today jumps from Mon to Tue")
    func earlierDayStart() {
        #expect(Self.logical(Day.tue, 3, latest: Day.mon) == Day.mon)
        #expect(Self.logical(Day.tue, 3, dayStart: 2 * 60, latest: Day.mon) == Day.tue)
    }

    @Test("Day start 02:00 → 05:00 at 03:00 Tue: Today stays Tue, and Wed starts at 05:00 Wed")
    func laterDayStart() {
        #expect(Self.logical(Day.tue, 3, dayStart: 2 * 60, latest: Day.mon) == Day.tue)
        #expect(Self.logical(Day.tue, 3, latest: Day.tue) == Day.tue)
        #expect(Self.logical(Day.wed, 4, latest: Day.tue) == Day.tue)
        #expect(Self.logical(Day.wed, 5, latest: Day.tue) == Day.wed)
    }

    @Test("A partner in Tokyo ticks the shared trash for their Tue while it's Mon at home: Mon stays open at home")
    func partnerAhead() {
        // Trash is a daily Habit (markMissed), as E5 states.
        let trash = TaskRecord(
            task: householdTask("trash", "Trash"),
            versions: [version("trash", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening],
                               policy: .markMissed, assignment: .anyOf([Person.alice, Person.bob]))],
            actions: [act(.complete, "trash", slot: SlotFixture.evening, for: nil, occurrence: Day.tue, by: Person.alice)]
        )
        let home = { (date: LogicalDate) in
            TodayBuilder.build(viewer: Person.bob, date: date, tasks: [trash], slots: SlotFixture.all, openMembers: Person.everyone).items(for: "trash")
        }
        #expect(home(Day.mon).map(\.occurrenceDate) == [Day.mon])
        #expect(home(Day.mon).map(\.resolution) == [.open])
        #expect(home(Day.tue).map(\.resolution) == [.done])
    }
}
