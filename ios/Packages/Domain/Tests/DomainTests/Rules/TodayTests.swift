import Testing
@testable import Domain

/// Domain model §6 — Today, as a function.
@Suite("§6 Today")
struct TodayTests {
    static func daily(_ id: TaskID, _ title: String, slot: SlotID, policy: MissPolicy = .vanish, _ actions: [OccurrenceAction] = []) -> TaskRecord {
        TaskRecord(
            task: personalTask(id, title),
            versions: [version(id, from: Day.mon, .days(every: 1, start: Day.mon), slots: [slot], policy: policy)],
            actions: actions
        )
    }

    @Test("Grouped by slot in sortOrder, Anytime last, and by title within a slot")
    func grouping() {
        let slots = [
            Slot(id: SlotFixture.anytime, householdId: SlotFixture.home, name: "Anytime", sortOrder: 0, isAnytime: true),
            Slot(id: SlotFixture.evening, householdId: SlotFixture.home, name: "Evening", sortOrder: 1),
            Slot(id: SlotFixture.morning, householdId: SlotFixture.home, name: "Morning", sortOrder: 2),
        ]
        let records = [
            Self.daily("a", "Stretch", slot: SlotFixture.morning),
            Self.daily("b", "Floss", slot: SlotFixture.evening),
            Self.daily("c", "Read", slot: SlotFixture.anytime),
            Self.daily("d", "Coffee", slot: SlotFixture.morning),
        ]
        let sections = TodayBuilder.build(viewer: Person.bob, date: Day.mon, tasks: records, slots: slots)
        #expect(sections.map { $0.slot?.id } == [SlotFixture.evening, SlotFixture.morning, SlotFixture.anytime])
        #expect(sections[1].items.map(\.task.title) == ["Coffee", "Stretch"])
    }

    @Test("A lane whose slot is archived or missing shows under Anytime, keeping its slot ID (DM-19)")
    func archivedOrMissingSlot() throws {
        var slots = SlotFixture.all
        slots[0] = Slot(id: SlotFixture.morning, householdId: SlotFixture.home, name: "Morning", sortOrder: 0, isArchived: true)
        let records = [
            Self.daily("a", "Stretch", slot: SlotFixture.morning),
            Self.daily("b", "Floss", slot: "slot-from-another-household"),
        ]
        let sections = TodayBuilder.build(viewer: Person.bob, date: Day.mon, tasks: records, slots: slots)
        #expect(sections.count == 1)
        let anytime = try #require(sections.first)
        #expect(anytime.slot?.id == SlotFixture.anytime)
        #expect(anytime.items.map(\.lane.slotId) == ["slot-from-another-household", SlotFixture.morning])
    }

    @Test("Items resolved today stay visible, shown checked")
    func resolvedTodayStays() {
        let record = Self.daily("a", "Stretch", slot: SlotFixture.morning, [act(.complete, "a", slot: SlotFixture.morning, occurrence: Day.tue)])
        let items = TodayBuilder.build(viewer: Person.bob, date: Day.tue, tasks: [record], slots: SlotFixture.all).allItems
        #expect(items.map(\.resolution) == [.done])
    }

    @Test("A late tick of an earlier date (acted on today) shows checked today")
    func lateTickShowsToday() {
        // Floating-style late tick on a vanish lane: occurrence Mon, done Tue.
        let record = TaskRecord(
            task: personalTask("a", "Stretch"),
            versions: [version("a", from: Day.mon, .weeks(every: 1, on: [.monday], start: Day.mon), slots: [SlotFixture.morning], policy: .vanish)],
            actions: [act(.complete, "a", slot: SlotFixture.morning, occurrence: Day.mon, actedOn: Day.tue)]
        )
        let items = TodayBuilder.build(viewer: Person.bob, date: Day.tue, tasks: [record], slots: SlotFixture.all).allItems
        #expect(items.map(\.occurrenceDate) == [Day.mon])
        #expect(items.map(\.resolution) == [.done])
    }

    @Test("Snoozed items are left out")
    func snoozedLeftOut() {
        let record = Self.daily("a", "Plants", slot: SlotFixture.anytime, policy: .carryOver,
                                [act(.snooze, "a", slot: SlotFixture.anytime, occurrence: Day.mon, snoozeUntil: Day.wed)])
        #expect(TodayBuilder.build(viewer: Person.bob, date: Day.tue, tasks: [record], slots: SlotFixture.all).allItems.isEmpty)
        #expect(TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [record], slots: SlotFixture.all).allItems.count == 1)
    }

    @Test("An archived task is hidden, though its actions are kept (C7)")
    func archivedTaskHidden() {
        var record = Self.daily("a", "Stretch", slot: SlotFixture.morning, [act(.complete, "a", slot: SlotFixture.morning, occurrence: Day.mon)])
        record.task.isArchived = true
        #expect(TodayBuilder.build(viewer: Person.bob, date: Day.mon, tasks: [record], slots: SlotFixture.all).allItems.isEmpty)
        let engine = RecurrenceEngine(record: record, today: Day.mon)
        #expect(engine.status(of: engine.lane(.profile(Person.bob), SlotFixture.morning), on: Day.mon) == .done)
    }

    @Test("Nothing appears before its due date (FR-07)")
    func nothingEarly() {
        let record = TaskRecord(
            task: personalTask("a", "Passport"),
            versions: [version("a", from: Day.mon, .once(date: Day.fri), slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: []
        )
        #expect(TodayBuilder.build(viewer: Person.bob, date: Day.thu, tasks: [record], slots: SlotFixture.all).allItems.isEmpty)
        #expect(TodayBuilder.build(viewer: Person.bob, date: Day.fri, tasks: [record], slots: SlotFixture.all).allItems.count == 1)
    }

    @Test("The viewer sees their personal lanes and household lanes they're assigned to or in the anyOf set")
    func visibility() {
        let alicesPersonal = TaskRecord(
            task: personalTask("yoga", "Yoga", owner: Person.alice),
            versions: [version("yoga", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning], policy: .vanish)],
            actions: []
        )
        let shared = TaskRecord(
            task: householdTask("dishes", "Dishes"),
            versions: [version("dishes", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver,
                               assignment: .anyOf([Person.alice, Person.bob]))],
            actions: []
        )
        let mine = Self.daily("floss", "Floss", slot: SlotFixture.evening)
        let ids = TodayBuilder.build(viewer: Person.bob, date: Day.mon, tasks: [alicesPersonal, shared, mine], slots: SlotFixture.all, openMembers: Person.everyone)
            .allItems.map(\.task.id)
        #expect(Set(ids) == ["dishes", "floss"])
    }
}
