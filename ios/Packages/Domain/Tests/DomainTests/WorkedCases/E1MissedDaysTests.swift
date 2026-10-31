import Testing
@testable import Domain

/// Domain model §7, E1 — Missed days. Today is Wed.
@Suite("E1 Missed days")
struct E1MissedDaysTests {
    static let floss = TaskRecord(
        task: personalTask("floss", "Floss"),
        versions: [version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed)],
        actions: [act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.mon)]
    )

    static let plantsVersion = version(
        "plants", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon),
        slots: [SlotFixture.anytime], policy: .carryOver
    )
    static let plants = TaskRecord(task: personalTask("plants", "Water plants"), versions: [plantsVersion], actions: [])

    static let stretch = TaskRecord(
        task: personalTask("stretch", "Stretch"),
        versions: [version("stretch", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning], policy: .vanish)],
        actions: []
    )

    static func today(_ date: LogicalDate, _ records: [TaskRecord]) -> [TodaySection] {
        TodayBuilder.build(viewer: Person.bob, date: date, tasks: records, slots: SlotFixture.all)
    }

    @Test("Floss (Habit): open on Wed, Tue missed, streak 0")
    func floss() {
        let items = Self.today(Day.wed, [Self.floss]).items(for: "floss")
        #expect(items.count == 1)
        #expect(items.first?.resolution == .open)
        #expect(items.first?.occurrenceDate == Day.wed)

        let engine = RecurrenceEngine(record: Self.floss, today: Day.wed)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.evening)
        #expect(engine.status(of: lane, on: Day.mon) == .done)
        #expect(engine.status(of: lane, on: Day.tue) == .missed)
        #expect(engine.streak(for: .profile(Person.bob)) == 0)
    }

    @Test("Water plants (Routine, Mon/Thu): one item overdue since Mon, 2 days, strong")
    func plantsOnWednesday() throws {
        let items = Self.today(Day.wed, [Self.plants]).items(for: "plants")
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.resolution == .open)
        #expect(item.occurrenceDate == Day.mon)
        #expect(item.overdueSince == Day.mon)
        #expect(item.daysOverdue == 2)
        #expect(item.nominalPeriod == 3.5)
        #expect(item.warning == .strong)
    }

    @Test("Water plants on Thu, still not done: one item, overdue since Mon")
    func plantsOnThursday() throws {
        let items = Self.today(Day.thu, [Self.plants]).items(for: "plants")
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.overdueSince == Day.mon)
        #expect(item.occurrenceDate == Day.thu)
        #expect(item.daysOverdue == 3)
    }

    @Test("Ticking the plants on Thu resolves Mon and Thu")
    func plantsTickedOnThursday() throws {
        let ticked = TaskRecord(
            task: Self.plants.task,
            versions: Self.plants.versions,
            actions: [act(.complete, "plants", slot: SlotFixture.anytime, occurrence: Day.thu)]
        )
        let engine = RecurrenceEngine(record: ticked, today: Day.thu)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.anytime)
        #expect(engine.status(of: lane, on: Day.mon) == .clearedByLater)
        #expect(engine.status(of: lane, on: Day.thu) == .done)

        let item = try #require(Self.today(Day.thu, [ticked]).items(for: "plants").first)
        #expect(item.resolution == .done)
    }

    @Test("Stretch (Nice to do): open on Wed, Mon and Tue neutral")
    func stretch() {
        let items = Self.today(Day.wed, [Self.stretch]).items(for: "stretch")
        #expect(items.map(\.resolution) == [.open])

        let engine = RecurrenceEngine(record: Self.stretch, today: Day.wed)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.morning)
        #expect(engine.status(of: lane, on: Day.mon) == .neutral)
        #expect(engine.status(of: lane, on: Day.tue) == .neutral)
    }
}
