import Testing
@testable import Domain

/// Domain model §5.2 (lanes), §5.3 (due dates), and §5.4 (resolution by miss policy).
@Suite("§5.2–§5.4 Lanes and resolution")
struct LaneAndResolutionTests {
    static func daily(_ policy: MissPolicy, from: LogicalDate = Day.mon, slots: [SlotID] = [SlotFixture.anytime], _ actions: [OccurrenceAction] = []) -> TaskRecord {
        TaskRecord(
            task: personalTask("t", "Task"),
            versions: [version("t", from: from, .days(every: 1, start: from), slots: slots, policy: policy)],
            actions: actions
        )
    }

    static let bobAnytime = Lane(taskId: "t", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)

    // MARK: §5.2

    @Test("personal → one lane per slot for the owner")
    func personalLanes() {
        let engine = RecurrenceEngine(record: Self.daily(.vanish, slots: [SlotFixture.morning, SlotFixture.evening]), today: Day.mon)
        #expect(engine.lanes() == [
            Lane(taskId: "t", assignee: .profile(Person.bob), slotId: SlotFixture.morning),
            Lane(taskId: "t", assignee: .profile(Person.bob), slotId: SlotFixture.evening),
        ])
    }

    @Test("each(ps) → one lane per profile with an open membership")
    func eachNeedsOpenMembership() {
        let record = TaskRecord(
            task: householdTask("t", "Task"),
            versions: [version("t", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime],
                               policy: .markMissed, assignment: .each([Person.carol, Person.dave]))],
            actions: []
        )
        let engine = RecurrenceEngine(record: record, today: Day.mon, openMembers: [Person.alice, Person.bob, Person.dave])
        #expect(engine.lanes().map(\.assignee) == [.profile(Person.dave)])
    }

    @Test("A lane removed from today's version drops from Today; its history stays readable")
    func removedLaneDrops() {
        let record = TaskRecord(
            task: personalTask("t", "Task"),
            versions: [
                version("t", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning, SlotFixture.evening], policy: .markMissed),
                version("t", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed),
            ],
            actions: [act(.complete, "t", slot: SlotFixture.morning, occurrence: Day.mon)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.wed)
        let morning = Lane(taskId: "t", assignee: .profile(Person.bob), slotId: SlotFixture.morning)
        #expect(!engine.lanes().contains(morning))
        #expect(engine.state(of: morning) == nil)
        #expect(engine.status(of: morning, on: Day.mon) == .done)
        #expect(engine.status(of: morning, on: Day.tue) == .missed)
        #expect(engine.status(of: morning, on: Day.wed) == .notDue)
    }

    // MARK: §5.4

    @Test("vanish: resolved only by an action for that date; an unresolved past date is neutral")
    func vanish() {
        let engine = RecurrenceEngine(record: Self.daily(.vanish, [act(.complete, "t", slot: SlotFixture.anytime, occurrence: Day.tue)]), today: Day.wed)
        #expect(engine.status(of: Self.bobAnytime, on: Day.mon) == .neutral)
        #expect(engine.status(of: Self.bobAnytime, on: Day.tue) == .done)
        #expect(engine.status(of: Self.bobAnytime, on: Day.wed) == .open)
        #expect(engine.status(of: Self.bobAnytime, on: Day.thu) == .upcoming)
        #expect(engine.state(of: Self.bobAnytime)?.occurrenceDate == Day.wed)
        #expect(engine.state(of: Self.bobAnytime)?.daysOverdue == 0)
    }

    @Test("markMissed: an unresolved past date is missed")
    func markMissed() {
        let engine = RecurrenceEngine(record: Self.daily(.markMissed, [act(.skip, "t", slot: SlotFixture.anytime, occurrence: Day.tue)]), today: Day.wed)
        #expect(engine.status(of: Self.bobAnytime, on: Day.mon) == .missed)
        #expect(engine.status(of: Self.bobAnytime, on: Day.tue) == .skipped)
    }

    @Test("carryOver: one item for the backlog; occurrenceDate is the latest unresolved due date")
    func carryOverBacklog() throws {
        let engine = RecurrenceEngine(record: Self.daily(.carryOver), today: Day.thu)
        let state = try #require(engine.state(of: Self.bobAnytime))
        #expect(state.occurrenceDate == Day.thu)
        #expect(state.overdueSince == Day.mon)
        #expect(state.daysOverdue == 3)
        #expect(engine.status(of: Self.bobAnytime, on: Day.tue) == .overdue)
    }

    @Test("carryOver: an orphan completion (not a due date) still resolves the earlier backlog (C6)")
    func orphanCompletion() throws {
        let record = TaskRecord(
            task: personalTask("t", "Task"),
            versions: [version("t", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: [act(.complete, "t", slot: SlotFixture.anytime, occurrence: Day.tue)]
        )
        let engine = RecurrenceEngine(record: record, today: Day.wed)
        #expect(engine.state(of: Self.bobAnytime) == nil)
        #expect(engine.status(of: Self.bobAnytime, on: Day.mon) == .clearedByLater)
    }

    @Test("carryOver: an action dated after this device's today is accepted and clears the earlier backlog (§4, E5)")
    func futureDatedActionClearsBacklog() {
        let record = Self.daily(.carryOver, [act(.complete, "t", slot: SlotFixture.anytime, for: Person.bob, occurrence: Day.tue)])
        let engine = RecurrenceEngine(record: record, today: Day.mon)
        #expect(engine.state(of: Self.bobAnytime) == nil)
        #expect(engine.status(of: Self.bobAnytime, on: Day.mon) == .clearedByLater)
    }

    @Test("Each due date follows the policy of the version in effect on it: misses before a switch to carryOver aren't carried")
    func policyPerDate() throws {
        let record = TaskRecord(
            task: personalTask("t", "Task"),
            versions: [
                version("t", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime], policy: .markMissed),
                version("t", from: Day.wed, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver),
            ],
            actions: []
        )
        let engine = RecurrenceEngine(record: record, today: Day.thu)
        #expect(engine.status(of: Self.bobAnytime, on: Day.tue) == .missed)
        #expect(try #require(engine.state(of: Self.bobAnytime)).overdueSince == Day.wed)
    }

    @Test("Revoked actions don't resolve anything")
    func revokedIgnored() {
        let engine = RecurrenceEngine(record: Self.daily(.markMissed, [act(.complete, "t", slot: SlotFixture.anytime, occurrence: Day.mon, revoked: true)]), today: Day.tue)
        #expect(engine.status(of: Self.bobAnytime, on: Day.mon) == .missed)
    }

    @Test("A snooze doesn't resolve anything")
    func snoozeDoesNotResolve() {
        let record = Self.daily(.carryOver, [act(.snooze, "t", slot: SlotFixture.anytime, occurrence: Day.mon, snoozeUntil: Day.wed)])
        #expect(RecurrenceEngine(record: record, today: Day.thu).state(of: Self.bobAnytime)?.overdueSince == Day.mon)
    }
}
