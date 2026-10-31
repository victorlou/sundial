import Testing
@testable import Domain

/// Rule-version and action validation: DM-04, DM-05, DM-07, §2.7, §5.1.
@Suite("Validation")
struct ValidationTests {
    static let bob = Scope.personal(Person.bob)

    static func errors(
        anchor: Anchor = .fixed, _ pattern: Pattern, slots: [SlotID] = [SlotFixture.anytime], policy: MissPolicy = .carryOver,
        assignment: Assignment = .personal, scope: Scope = bob, seed: LogicalDate? = nil
    ) -> [RuleValidationError] {
        version("t", from: Day.wed, anchor: anchor, pattern, slots: slots, policy: policy, assignment: assignment, seed: seed)
            .validate(scope: scope, today: Day.wed)
    }

    @Test("Valid rules for every P1 pattern and preset pass")
    func validRules() {
        #expect(Self.errors(.once(date: nil)).isEmpty)
        #expect(Self.errors(.once(date: Day.fri)).isEmpty)
        #expect(Self.errors(.days(every: 3, start: Day.mon), policy: .markMissed).isEmpty)
        #expect(Self.errors(.weeks(every: 2, on: [.monday], start: Day.mon), policy: .vanish).isEmpty)
        #expect(Self.errors(.months(every: 1, on: .day(31), start: Day.mon)).isEmpty)
        #expect(Self.errors(.months(every: 1, on: .weekday(.last, .saturday), start: Day.mon)).isEmpty)
        #expect(Self.errors(anchor: .floating, .days(every: 7, start: Day.wed), seed: Day.wed).isEmpty)
        #expect(Self.errors(anchor: .floating, .weeks(every: 2, on: [], start: Day.wed), seed: Day.wed).isEmpty)
        #expect(Self.errors(anchor: .floating, .months(every: 1, on: nil, start: Day.wed), seed: Day.wed).isEmpty)
    }

    @Test("Floating needs exactly one slot, carryOver, and a seed (DM-04)")
    func floatingRules() {
        let floating = { (slots: [SlotID], policy: MissPolicy, seed: LogicalDate?) in
            Self.errors(anchor: .floating, .days(every: 7, start: Day.wed), slots: slots, policy: policy, seed: seed)
        }
        #expect(floating([SlotFixture.morning, SlotFixture.evening], .carryOver, Day.wed) == [.floatingNeedsOneSlot])
        #expect(floating([SlotFixture.anytime], .markMissed, Day.wed) == [.floatingNeedsCarryOver])
        #expect(floating([SlotFixture.anytime], .carryOver, nil) == [.floatingNeedsSeed])
    }

    @Test("Floating allows only every-n days, weeks, or months")
    func floatingPatterns() {
        #expect(Self.errors(anchor: .floating, .once(date: nil), seed: Day.wed) == [.patternNotAllowedForFloating])
        #expect(Self.errors(anchor: .floating, .weeks(every: 1, on: [.monday], start: Day.wed), seed: Day.wed) == [.patternNotAllowedForFloating])
        #expect(Self.errors(anchor: .floating, .months(every: 1, on: .day(1), start: Day.wed), seed: Day.wed) == [.patternNotAllowedForFloating])
    }

    @Test("Pattern parameters")
    func patternParameters() {
        #expect(Self.errors(.days(every: 0, start: Day.wed)) == [.intervalMustBePositive])
        #expect(Self.errors(.weeks(every: 1, on: [], start: Day.wed)) == [.noWeekdays])
        #expect(Self.errors(.months(every: 1, on: nil, start: Day.wed)) == [.missingMonthDay])
        #expect(Self.errors(.months(every: 1, on: .day(32), start: Day.wed)) == [.invalidMonthDay])
        #expect(Self.errors(.months(every: 1, on: .day(0), start: Day.wed)) == [.invalidMonthDay])
        #expect(Self.errors(.once(date: Day.tue)) == [.onceDateBeforeEffectiveFrom])
    }

    @Test("Slots and assignment")
    func slotsAndAssignment() {
        #expect(Self.errors(.days(every: 1, start: Day.wed), slots: []) == [.noSlots])
        #expect(Self.errors(.days(every: 1, start: Day.wed), slots: [SlotFixture.anytime, SlotFixture.anytime]) == [.duplicateSlots])
        #expect(Self.errors(.days(every: 1, start: Day.wed), assignment: .each([Person.carol])) == [.assignmentDoesNotMatchScope])
        #expect(Self.errors(.days(every: 1, start: Day.wed), scope: .household(SlotFixture.home)) == [.assignmentDoesNotMatchScope])
        #expect(Self.errors(.days(every: 1, start: Day.wed), assignment: .anyOf([]), scope: .household(SlotFixture.home)) == [.emptyAssignment])
        #expect(Self.errors(.days(every: 1, start: Day.wed), assignment: .each([Person.carol, Person.carol]), scope: .household(SlotFixture.home)) == [.duplicateAssignees])
    }

    // MARK: Actions

    static let floss = TaskRecord(
        task: personalTask("floss", "Floss"),
        versions: [version("floss", from: Day.prevMon, .days(every: 1, start: Day.prevMon), slots: [SlotFixture.evening], policy: .markMissed)],
        actions: []
    )

    @Test("Backfill: actedOn within today−7…today (DM-07)")
    func backfillWindow() {
        let engine = RecurrenceEngine(record: Self.floss, today: Day.wed)
        #expect(engine.validate(act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed - 7)).isEmpty)
        #expect(engine.validate(act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed - 8)) == [.outsideBackfillWindow])
        #expect(engine.validate(act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.thu)) == [.inFuture])
    }

    @Test("On vanish/markMissed lanes the occurrence is in the window too; on carryOver it can be older")
    func occurrenceWindow() {
        let floss = RecurrenceEngine(record: Self.floss, today: Day.wed)
        #expect(floss.validate(act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.wed - 8, actedOn: Day.wed)) == [.outsideBackfillWindow])

        let monthly = TaskRecord(
            task: personalTask("bills", "Pay bills"),
            versions: [version("bills", from: LogicalDate(year: 2026, month: 9, day: 1), .months(every: 1, on: .day(1), start: LogicalDate(year: 2026, month: 9, day: 1)),
                               slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: []
        )
        let engine = RecurrenceEngine(record: monthly, today: LogicalDate(year: 2026, month: 9, day: 20))
        #expect(engine.validate(act(.complete, "bills", slot: SlotFixture.anytime, occurrence: LogicalDate(year: 2026, month: 9, day: 1),
                                    actedOn: LogicalDate(year: 2026, month: 9, day: 20))).isEmpty)
    }

    @Test("A snooze needs a snoozeUntil")
    func snoozeNeedsDate() {
        let plants = TaskRecord(
            task: personalTask("plants", "Plants"),
            versions: [version("plants", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: []
        )
        let engine = RecurrenceEngine(record: plants, today: Day.wed)
        #expect(engine.validate(act(.snooze, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed)) == [.snoozeUntilNotAfterActedOn])
    }
}
