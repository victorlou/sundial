import Testing
@testable import Domain

/// Domain model §7, E3 — Changing the rules after history exists. Every change is made on Wed.
@Suite("E3 Changing the rules")
struct E3RuleChangesTests {
    @Test("Sheets 7 d → 10 d, last done 9 days ago: next due Thu, no longer overdue")
    func sheetsIntervalChange() throws {
        let v7 = version("sheets", from: Day.prevMon, anchor: .floating, .days(every: 7, start: Day.prevMon),
                         slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon)
        let v10 = version("sheets", from: Day.wed, anchor: .floating, .days(every: 10, start: Day.wed),
                          slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon)
        let done = act(.complete, "sheets", slot: SlotFixture.anytime, occurrence: Day.prevMon)
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        let task = personalTask("sheets", "Change sheets")

        let before = RecurrenceEngine(record: TaskRecord(task: task, versions: [v7], actions: [done]), today: Day.wed)
        #expect(before.state(of: lane)?.daysOverdue == 2)

        let after = TaskRecord(task: task, versions: [v7, v10], actions: [done])
        #expect(RecurrenceEngine(record: after, today: Day.wed).state(of: lane) == nil)
        let thu = try #require(RecurrenceEngine(record: after, today: Day.thu).state(of: lane))
        #expect(thu.occurrenceDate == Day.thu)
        #expect(thu.daysOverdue == 0)
    }

    @Test("Plants Mon/Thu → Tue/Fri with a backlog since Mon: still open since Mon, next due Fri and the following Tue")
    func plantsWeekdayChange() throws {
        let record = TaskRecord(
            task: personalTask("plants", "Water plants"),
            versions: [
                version("plants", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon),
                        slots: [SlotFixture.anytime], policy: .carryOver),
                version("plants", from: Day.wed, .weeks(every: 1, on: [.tuesday, .friday], start: Day.wed),
                        slots: [SlotFixture.anytime], policy: .carryOver),
            ],
            actions: []
        )
        let engine = RecurrenceEngine(record: record, today: Day.wed)
        let lane = engine.lane(.profile(Person.bob), SlotFixture.anytime)
        let state = try #require(engine.state(of: lane))
        #expect(state.overdueSince == Day.mon)
        #expect(state.occurrenceDate == Day.mon)

        #expect(engine.isDue(lane, on: Day.tue) == false) // old version: not a Mon/Thu
        #expect(engine.isDue(lane, on: Day.thu) == false) // new version: not a Tue/Fri
        #expect(engine.isDue(lane, on: Day.fri))
        #expect(engine.isDue(lane, on: Day.nextTue))
    }

    static func floss(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("floss", "Floss"),
            versions: [
                version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed),
                version("floss", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning, SlotFixture.evening], policy: .markMissed),
            ],
            actions: actions
        )
    }

    @Test("Floss adds a Morning slot: a new lane from Wed, Evening history untouched, streak groups slots per day")
    func flossAddsMorning() {
        let evening = { (day: LogicalDate) in act(.complete, "floss", slot: SlotFixture.evening, occurrence: day) }
        let morning = { (day: LogicalDate) in act(.complete, "floss", slot: SlotFixture.morning, occurrence: day) }

        let record = Self.floss([evening(Day.mon), evening(Day.tue), evening(Day.wed)])
        let engine = RecurrenceEngine(record: record, today: Day.wed)
        let morningLane = engine.lane(.profile(Person.bob), SlotFixture.morning)
        let eveningLane = engine.lane(.profile(Person.bob), SlotFixture.evening)

        #expect(engine.lanes().count == 2)
        #expect(engine.isDue(morningLane, on: Day.tue) == false)
        #expect(engine.isDue(morningLane, on: Day.wed))
        #expect(engine.status(of: eveningLane, on: Day.mon) == .done)
        #expect(engine.status(of: eveningLane, on: Day.tue) == .done)

        let today = TodayBuilder.build(viewer: Person.bob, date: Day.wed, tasks: [record], slots: SlotFixture.all)
        #expect(today.items(for: "floss").count == 2)

        // Wed counts only once both slots are done.
        #expect(engine.streak(for: .profile(Person.bob)) == 2)
        let bothDone = Self.floss([evening(Day.mon), evening(Day.tue), evening(Day.wed), morning(Day.wed)])
        #expect(RecurrenceEngine(record: bothDone, today: Day.wed).streak(for: .profile(Person.bob)) == 3)

        // On Thu, a Wed with the morning missed breaks it.
        #expect(RecurrenceEngine(record: record, today: Day.thu).streak(for: .profile(Person.bob)) == 0)
    }

    @Test("Trash duty each(Dave) → each(Carol, Dave): Carol's lane starts Wed, Dave's continues")
    func trashAddsCarol() {
        let record = TaskRecord(
            task: householdTask("trash", "Trash duty"),
            versions: [
                version("trash", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening],
                        policy: .markMissed, assignment: .each([Person.dave])),
                version("trash", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening],
                        policy: .markMissed, assignment: .each([Person.carol, Person.dave])),
            ],
            actions: [act(.complete, "trash", slot: SlotFixture.evening, for: Person.dave, occurrence: Day.mon)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.wed, openMembers: Person.everyone)
        #expect(Set(engine.lanes().map(\.assignee)) == [.profile(Person.carol), .profile(Person.dave)])

        let carol = engine.lane(.profile(Person.carol), SlotFixture.evening)
        let dave = engine.lane(.profile(Person.dave), SlotFixture.evening)
        #expect(engine.isDue(carol, on: Day.tue) == false)
        #expect(engine.isDue(carol, on: Day.wed))
        #expect(engine.status(of: dave, on: Day.mon) == .done)
        #expect(engine.status(of: dave, on: Day.tue) == .missed)
    }

    @Test("Dishwasher each(Carol, Dave) → anyOf(Carol, Dave): per-profile lanes and their backlog drop, one shared lane starts Wed")
    func dishwasherBecomesShared() throws {
        let record = TaskRecord(
            task: householdTask("dishwasher", "Empty dishwasher"),
            versions: [
                version("dishwasher", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime],
                        policy: .carryOver, assignment: .each([Person.carol, Person.dave])),
                version("dishwasher", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime],
                        policy: .carryOver, assignment: .anyOf([Person.carol, Person.dave])),
            ],
            actions: []
        )
        let engine = RecurrenceEngine(record: record, today: Day.wed, openMembers: Person.everyone)
        #expect(engine.lanes().map(\.assignee) == [.shared])

        for viewer in [Person.carol, Person.dave] {
            let items = TodayBuilder.build(viewer: viewer, date: Day.wed, tasks: [record], slots: SlotFixture.all, openMembers: Person.everyone)
                .items(for: "dishwasher")
            #expect(items.count == 1)
            let item = try #require(items.first)
            #expect(item.lane.assignee == .shared)
            #expect(item.overdueSince == Day.wed)
            #expect(item.daysOverdue == 0)
        }
    }

    @Test("Sheets floating → fixed every Sat: the first fixed due date is Sat, the floating overdue state is dropped")
    func sheetsBecomeFixed() throws {
        let record = TaskRecord(
            task: personalTask("sheets", "Change sheets"),
            versions: [
                version("sheets", from: Day.prevMon, anchor: .floating, .days(every: 7, start: Day.prevMon),
                        slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon),
                version("sheets", from: Day.wed, .weeks(every: 1, on: [.saturday], start: Day.wed),
                        slots: [SlotFixture.anytime], policy: .carryOver),
            ],
            actions: [act(.complete, "sheets", slot: SlotFixture.anytime, occurrence: Day.prevMon)]
        )
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        #expect(RecurrenceEngine(record: record, today: Day.wed).state(of: lane) == nil)
        #expect(RecurrenceEngine(record: record, today: Day.fri).state(of: lane) == nil)
        let sat = try #require(RecurrenceEngine(record: record, today: Day.sat).state(of: lane))
        #expect(sat.overdueSince == Day.sat)
        #expect(sat.daysOverdue == 0)
    }

    @Test("A change effective last week isn't allowed")
    func noPastChanges() {
        let lastWeek = version("floss", from: Day.prevMon, .days(every: 1, start: Day.prevMon), slots: [SlotFixture.evening], policy: .markMissed)
        #expect(lastWeek.validate(scope: .personal(Person.bob), today: Day.wed).contains(.effectiveFromInPast))

        let fromToday = version("floss", from: Day.wed, .days(every: 1, start: Day.wed), slots: [SlotFixture.evening], policy: .markMissed)
        #expect(fromToday.validate(scope: .personal(Person.bob), today: Day.wed).isEmpty)
    }
}
