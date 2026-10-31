import Testing
@testable import Domain

/// Domain model §5.6 (presets), §5.7 (warning level), and §5.8 (snooze).
@Suite("§5.6–§5.8 Presets, warnings, snooze")
struct PresetWarningSnoozeTests {
    // MARK: §5.6

    @Test("Each preset is an anchor and a miss policy", arguments: [
        (Preset.habit, Anchor.fixed, MissPolicy.markMissed),
        (.routineChore, .fixed, .carryOver),
        (.everySoOften, .floating, .carryOver),
        (.niceToDo, .fixed, .vanish),
        (.toDo, .fixed, .carryOver),
    ])
    func presets(preset: Preset, anchor: Anchor, policy: MissPolicy) {
        #expect(preset.anchor == anchor)
        #expect(preset.missPolicy == policy)
    }

    @Test("A rule's preset name, if it matches one; To-do is the once pattern")
    func matchingPreset() {
        let daily = Pattern.days(every: 1, start: Day.mon)
        #expect(Preset.matching(anchor: .fixed, missPolicy: .markMissed, pattern: daily) == .habit)
        #expect(Preset.matching(anchor: .fixed, missPolicy: .carryOver, pattern: daily) == .routineChore)
        #expect(Preset.matching(anchor: .fixed, missPolicy: .carryOver, pattern: .once(date: nil)) == .toDo)
        #expect(Preset.matching(anchor: .floating, missPolicy: .carryOver, pattern: daily) == .everySoOften)
        #expect(Preset.matching(anchor: .fixed, missPolicy: .vanish, pattern: daily) == .niceToDo)
        #expect(Preset.matching(anchor: .fixed, missPolicy: .markMissed, pattern: .once(date: nil)) == nil)
        #expect(Preset.toDo.isOnce && !Preset.habit.isOnce)
    }

    // MARK: §5.7

    @Test("Nominal periods")
    func nominalPeriods() {
        #expect(Pattern.days(every: 3, start: Day.mon).nominalPeriod == 3)
        #expect(Pattern.weeks(every: 1, on: [.monday, .thursday], start: Day.mon).nominalPeriod == 3.5)
        #expect(Pattern.weeks(every: 2, on: [.saturday], start: Day.mon).nominalPeriod == 14)
        #expect(Pattern.weeks(every: 2, on: [], start: Day.mon).nominalPeriod == 14) // floating
        #expect(Pattern.months(every: 2, on: .day(1), start: Day.mon).nominalPeriod == 60)
        #expect(Pattern.once(date: nil).nominalPeriod == 7)
    }

    @Test("Warning levels from r = daysOverdue / nominalPeriod", arguments: [
        (0, 7.0, WarningLevel.none),
        (1, 7.0, .mild),
        (3, 7.0, .mild),
        (4, 7.0, .strong),
        (2, 3.5, .strong),
        (6, 7.0, .strong),
        (7, 7.0, .severe),
        (30, 7.0, .severe),
    ])
    func levels(days: Int, period: Double, level: WarningLevel) {
        #expect(WarningLevel(daysOverdue: days, nominalPeriod: period) == level)
    }

    @Test("Thresholds are tunable presentation settings")
    func tunableThresholds() {
        let strict = WarningThresholds(strong: 0.25, severe: 0.5)
        #expect(WarningLevel(daysOverdue: 2, nominalPeriod: 7, thresholds: strict) == .strong)
        #expect(WarningLevel(daysOverdue: 4, nominalPeriod: 7, thresholds: strict) == .severe)
    }

    // MARK: §5.8

    static let lane = Lane(taskId: "plants", assignee: .profile(Person.bob), slotId: SlotFixture.anytime)

    static func plants(_ actions: [OccurrenceAction]) -> TaskRecord {
        TaskRecord(
            task: personalTask("plants", "Water plants"),
            versions: [version("plants", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon),
                               slots: [SlotFixture.anytime], policy: .carryOver)],
            actions: actions
        )
    }

    static func snooze(on day: LogicalDate, until: LogicalDate, revoked: Bool = false) -> OccurrenceAction {
        act(.snooze, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: day, snoozeUntil: until, revoked: revoked)
    }

    @Test("Snooze is only for carryOver and floating lanes (DM-05)")
    func snoozeOnlyCarryOverOrFloating() {
        let snooze = act(.snooze, "floss", slot: SlotFixture.evening, occurrence: Day.wed, snoozeUntil: Day.fri)
        let floss = TaskRecord(
            task: personalTask("floss", "Floss"),
            versions: [version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.evening], policy: .markMissed)],
            actions: []
        )
        #expect(RecurrenceEngine(record: floss, today: Day.wed).validate(snooze).contains(.snoozeNotAllowed))

        let plantsSnooze = Self.snooze(on: Day.wed, until: Day.fri)
        #expect(RecurrenceEngine(record: Self.plants([]), today: Day.wed).validate(plantsSnooze).isEmpty)

        let noDate = act(.snooze, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed, snoozeUntil: Day.wed)
        #expect(RecurrenceEngine(record: Self.plants([]), today: Day.wed).validate(noDate).contains(.snoozeUntilNotAfterActedOn))
    }

    @Test("Hidden while today < snoozeUntil; daysOverdue keeps counting")
    func hiddenUntil() throws {
        let record = Self.plants([Self.snooze(on: Day.tue, until: Day.wed)])
        let tue = try #require(RecurrenceEngine(record: record, today: Day.tue).state(of: Self.lane))
        #expect(tue.isSnoozed)
        #expect(tue.snoozedUntil == Day.wed)
        #expect(tue.daysOverdue == 1)
        let wed = try #require(RecurrenceEngine(record: record, today: Day.wed).state(of: Self.lane))
        #expect(!wed.isSnoozed)
        #expect(wed.daysOverdue == 2)
    }

    @Test("A resolving action since the snooze ends it, even when the lane is due again before snoozeUntil")
    func resolvingEndsSnooze() throws {
        let record = Self.plants([
            Self.snooze(on: Day.tue, until: Day.sat),
            act(.complete, "plants", slot: SlotFixture.anytime, occurrence: Day.mon, actedOn: Day.wed),
        ])
        let thu = try #require(RecurrenceEngine(record: record, today: Day.thu).state(of: Self.lane))
        #expect(thu.overdueSince == Day.thu)
        #expect(!thu.isSnoozed)
    }

    @Test("The latest unrevoked snooze wins; same-day ties go to the later snoozeUntil")
    func latestSnoozeWins() {
        let later = Self.plants([Self.snooze(on: Day.mon, until: Day.sat), Self.snooze(on: Day.tue, until: Day.wed)])
        #expect(RecurrenceEngine(record: later, today: Day.wed).state(of: Self.lane)?.isSnoozed == false)

        let revoked = Self.plants([Self.snooze(on: Day.mon, until: Day.sat), Self.snooze(on: Day.tue, until: Day.wed + 7, revoked: true)])
        #expect(RecurrenceEngine(record: revoked, today: Day.fri).state(of: Self.lane)?.snoozedUntil == Day.sat)

        let sameDay = Self.plants([Self.snooze(on: Day.tue, until: Day.wed), Self.snooze(on: Day.tue, until: Day.fri)])
        #expect(RecurrenceEngine(record: sameDay, today: Day.wed).state(of: Self.lane)?.snoozedUntil == Day.fri)
    }
}
