import Testing
@testable import Domain

/// Architecture §7's property-style test: undoing any action restores the previous Today.
/// For a mix of tasks, on every day of a few weeks, tick, skip, or snooze each open item, revoke it, and compare.
@Suite("Undo restores Today")
struct UndoPropertyTests {
    static let records: [TaskRecord] = [
        TaskRecord(task: personalTask("floss", "Floss"),
                   versions: [version("floss", from: Day.mon, .days(every: 1, start: Day.mon), slots: [SlotFixture.morning, SlotFixture.evening], policy: .markMissed)],
                   actions: [act(.complete, "floss", slot: SlotFixture.evening, occurrence: Day.mon)]),
        TaskRecord(task: personalTask("plants", "Water plants"),
                   versions: [version("plants", from: Day.mon, .weeks(every: 1, on: [.monday, .thursday], start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver)],
                   actions: []),
        TaskRecord(task: personalTask("stretch", "Stretch"),
                   versions: [version("stretch", from: Day.mon, .days(every: 2, start: Day.mon), slots: [SlotFixture.morning], policy: .vanish)],
                   actions: []),
        TaskRecord(task: personalTask("sheets", "Change sheets"),
                   versions: [version("sheets", from: Day.prevMon, anchor: .floating, .days(every: 4, start: Day.prevMon), slots: [SlotFixture.anytime], policy: .carryOver, seed: Day.prevMon)],
                   actions: []),
        TaskRecord(task: personalTask("passport", "Renew passport"),
                   versions: [version("passport", from: Day.tue, .once(date: nil), slots: [SlotFixture.anytime], policy: .carryOver)],
                   actions: []),
        TaskRecord(task: personalTask("bills", "Pay bills"),
                   versions: [version("bills", from: Day.mon, .months(every: 1, on: .weekday(.first, .saturday), start: Day.mon), slots: [SlotFixture.anytime], policy: .carryOver)],
                   actions: []),
    ]

    static func today(_ records: [TaskRecord], _ date: LogicalDate) -> [TodaySection] {
        TodayBuilder.build(viewer: Person.bob, date: date, tasks: records, slots: SlotFixture.all)
    }

    @Test("Every tick, skip, or snooze, once revoked, leaves Today as it was", arguments: 0..<21)
    func undoRestoresToday(offset: Int) {
        let date = Day.mon + offset
        let before = Self.today(Self.records, date)
        for item in before.allItems where item.resolution == .open {
            var kinds: [ActionKind] = [.complete, .skip]
            let version = RecurrenceEngine(record: Self.records.first { $0.task.id == item.task.id }!, today: date).version(on: date)!
            if version.anchor == .floating || version.missPolicy == .carryOver { kinds.append(.snooze) }
            for kind in kinds {
                let action = act(kind, item.task.id, slot: item.lane.slotId, occurrence: item.occurrenceDate, actedOn: date,
                                 snoozeUntil: kind == .snooze ? date + 2 : nil, revoked: true)
                let records = Self.records.map { record in
                    record.task.id == item.task.id
                        ? TaskRecord(task: record.task, versions: record.versions, actions: record.actions + [action])
                        : record
                }
                #expect(Self.today(records, date) == before, "\(kind) on \(item.task.title) at \(date)")
            }
        }
    }

    @Test("And an unrevoked tick or skip actually changes it", arguments: 0..<21)
    func actionsChangeToday(offset: Int) {
        let date = Day.mon + offset
        let before = Self.today(Self.records, date)
        for item in before.allItems where item.resolution == .open {
            let action = act(.complete, item.task.id, slot: item.lane.slotId, occurrence: item.occurrenceDate, actedOn: date)
            let records = Self.records.map { record in
                record.task.id == item.task.id
                    ? TaskRecord(task: record.task, versions: record.versions, actions: record.actions + [action])
                    : record
            }
            let after = Self.today(records, date).allItems.first { $0.task.id == item.task.id && $0.lane == item.lane }
            #expect(after?.resolution == .done, "tick on \(item.task.title) at \(date)")
        }
    }
}
