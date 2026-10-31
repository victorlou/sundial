import Testing
@testable import Domain

/// Domain model §5.9 (streaks and averages) and §5.10 (lane continuity across slot remaps).
@Suite("§5.9–§5.10 Stats and remaps")
struct StatsAndRemapTests {
    // MARK: §5.9 streaks

    static func habit(slots: [SlotID], _ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("h", "Habit"),
            versions: [version("h", from: Day.mon, .days(every: 1, start: Day.mon), slots: slots, policy: .markMissed)],
            actions: actions
        )
    }

    static func on(_ kind: ActionKind, _ slot: SlotID, _ day: LogicalDate) -> OccurrenceAction {
        act(kind, "h", slot: slot, occurrence: day)
    }

    @Test("Counts consecutive due dates back from yesterday; today adds once done and never breaks while open")
    func streakBasics() {
        let three = Self.habit(slots: [SlotFixture.evening], [Self.on(.complete, SlotFixture.evening, Day.mon), Self.on(.complete, SlotFixture.evening, Day.tue)])
        #expect(RecurrenceEngine(record: three, today: Day.wed).streak(for: .profile(Person.bob)) == 2)

        let doneToday = Self.habit(slots: [SlotFixture.evening], [Day.mon, Day.tue, Day.wed].map { Self.on(.complete, SlotFixture.evening, $0) })
        #expect(RecurrenceEngine(record: doneToday, today: Day.wed).streak(for: .profile(Person.bob)) == 3)
    }

    @Test("A date where everything was skipped neither breaks nor adds; a partly skipped, otherwise done date adds")
    func streakSkips() {
        let record = Self.habit(slots: [SlotFixture.morning, SlotFixture.evening], [
            Self.on(.complete, SlotFixture.morning, Day.mon), Self.on(.complete, SlotFixture.evening, Day.mon),
            Self.on(.skip, SlotFixture.morning, Day.tue), Self.on(.skip, SlotFixture.evening, Day.tue),
            Self.on(.skip, SlotFixture.morning, Day.wed), Self.on(.complete, SlotFixture.evening, Day.wed),
        ])
        #expect(RecurrenceEngine(record: record, today: Day.thu).streak(for: .profile(Person.bob)) == 2)
    }

    @Test("Only days that are due count: Mon/Thu habits skip the days between")
    func streakOnlyDueDates() {
        let record = TaskRecord(
            task: personalTask("h", "Habit"),
            versions: [version("h", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed)],
            actions: [Self.on(.complete, SlotFixture.evening, Day.mon), Self.on(.complete, SlotFixture.evening, Day.thu)]
        )
        #expect(RecurrenceEngine(record: record, today: Day.nextMon).streak(for: .profile(Person.bob)) == 2)
    }

    @Test("Streaks are per assignee for each(ps) lanes")
    func streakPerAssignee() {
        let record = TaskRecord(
            task: householdTask("teeth", "Brush teeth"),
            versions: [version("teeth", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening],
                               policy: .markMissed, assignment: .each([Person.carol, Person.dave]))],
            actions: [act(.complete, "teeth", slot: SlotFixture.evening, for: Person.carol, occurrence: Day.mon)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.tue, openMembers: Person.everyone)
        #expect(engine.streak(for: .profile(Person.carol)) == 1)
        #expect(engine.streak(for: .profile(Person.dave)) == 0)
    }

    // MARK: §5.9 averages

    static func floating(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("f", "Floating"),
            versions: [version("f", from: Day.prevMon - 30, anchor: .floating, .days(every: 7, start: Day.prevMon - 30),
                               slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon - 30)],
            actions: actions
        )
    }

    @Test("Average interval: the mean gap between the last 5 completion dates; skips and revoked ticks left out")
    func averageInterval() {
        let base = Day.prevMon - 30
        let lane = Lane(taskId: "f", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        let actions = [0, 5, 13, 20, 26, 34].map { act(.complete, "f", slot: SlotFixture.anytime, occurrence: base + $0) }
            + [act(.skip, "f", slot: SlotFixture.anytime, occurrence: base + 40)]
            + [act(.complete, "f", slot: SlotFixture.anytime, occurrence: base + 45, revoked: true)]
        // The last five are days 5, 13, 20, 26, 34: gaps 8, 7, 6, 8.
        #expect(RecurrenceEngine(record: Self.floating(actions), today: Day.wed).averageInterval(of: lane) == 7.25)
    }

    @Test("Average interval counts each date once (C1) and needs two dates")
    func averageIntervalEdges() {
        let lane = Lane(taskId: "f", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        let one = [act(.complete, "f", slot: SlotFixture.anytime, occurrence: Day.mon)]
        #expect(RecurrenceEngine(record: Self.floating(one), today: Day.wed).averageInterval(of: lane) == nil)

        let twice = one + [act(.complete, "f", slot: SlotFixture.anytime, occurrence: Day.mon, id: "ipad"),
                           act(.complete, "f", slot: SlotFixture.anytime, occurrence: Day.mon + 6)]
        #expect(RecurrenceEngine(record: Self.floating(twice), today: Day.wed).averageInterval(of: lane) == 6)
    }

    // MARK: §5.10

    static let oldMorning: SlotID = "old-morning"
    static let oldAnytime: SlotID = "old-anytime"

    @Test("A remap version carries the carry-over backlog to the new slot")
    func remapCarriesBacklog() throws {
        let record = TaskRecord(
            task: personalTask("plants", "Water plants"),
            versions: [
                version("plants", from: Day.mon, .days(every: 1, start: Day.mon), slots: [Self.oldMorning], policy: .carryOver),
                version("plants", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning], policy: .carryOver,
                        slotMap: [Self.oldMorning: SlotFixture.morning]),
            ],
            actions: [act(.complete, "plants", slot: Self.oldMorning, occurrence: Day.mon)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.thu)
        let lane = try #require(engine.lanes().first)
        #expect(lane.slotId == SlotFixture.morning)
        let state = try #require(engine.state(of: lane))
        #expect(state.overdueSince == Day.tue)
        #expect(engine.status(of: lane, on: Day.mon) == .done)
    }

    @Test("A remap version carries a floating clock, including ticks recorded under the old slot after the remap")
    func remapCarriesFloatingClock() {
        let record = TaskRecord(
            task: personalTask("sheets", "Change sheets"),
            versions: [
                version("sheets", from: Day.prevMon, anchor: .floating, .days(every: 7, start: Day.prevMon), slots: [Self.oldAnytime],
                        policy: .carryOver, seed: Day.prevMon),
                version("sheets", from: Day.tue, anchor: .floating, .days(every: 7, start: Day.prevMon), slots: [SlotFixture.anytime],
                        policy: .carryOver, seed: Day.prevMon, slotMap: [Self.oldAnytime: SlotFixture.anytime]),
            ],
            // An offline device ticked under the old slot ID on Wed, after the remap.
            actions: [act(.complete, "sheets", slot: Self.oldAnytime, occurrence: Day.mon, actedOn: Day.wed)]
        )
        let lane = Lane(taskId: "sheets", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)
        #expect(RecurrenceEngine(record: record, today: Day.wed).state(of: lane)?.resolution == .done)
        #expect(RecurrenceEngine(record: record, today: Day.nextTue).state(of: lane) == nil)
        #expect(RecurrenceEngine(record: record, today: Day.nextWed).state(of: lane)?.resolution == .open)
    }

    @Test("Several remaps in a row carry the lane across each in turn, even back to an earlier slot")
    func remapChain() throws {
        let away: SlotID = "away-evening"
        let record = TaskRecord(
            task: personalTask("floss", "Floss"),
            versions: [
                version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed),
                version("floss", from: Day.tue, .days(every: 1, start: Day.mon), slots: [away], policy: .markMissed,
                        slotMap: [SlotFixture.evening: away]),
                version("floss", from: Day.thu, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed,
                        slotMap: [away: SlotFixture.evening]),
            ],
            actions: [Day.mon, Day.wed, Day.thu].map { act(.complete, "floss", slot: $0 == Day.wed ? away : SlotFixture.evening, occurrence: $0) }
                + [act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.tue)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.fri)
        #expect(engine.lanes().count == 1)
        let lane = try #require(engine.lanes().first)
        for day in [Day.mon, Day.tue, Day.wed, Day.thu] {
            #expect(engine.status(of: lane, on: day) == .done)
        }
        #expect(engine.streak(for: .profile(Person.bob)) == 4)
    }
}
