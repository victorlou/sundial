import Testing
@testable import Domain

/// Domain model §7, E4 — Shared and assigned tasks, on Mon.
/// The household board itself is P3/P4, so these check the lanes and each person's Today, which the board is built from.
@Suite("E4 Shared and assigned tasks")
struct E4SharedTasksTests {
    static func today(_ viewer: ProfileID, _ records: [TaskRecord], date: LogicalDate = Day.mon) -> [TodaySection] {
        TodayBuilder.build(viewer: viewer, date: date, tasks: records, slots: SlotFixture.all, openMembers: Person.everyone)
    }

    static func daily(_ id: TaskID, _ title: String, slots: [SlotID], _ assignment: Assignment) -> TaskRecord {
        TaskRecord(
            task: householdTask(id, title),
            versions: [version(id, from: Day.mon, .days(every: 1, start: Day.mon), slots: slots, policy: .markMissed, assignment: assignment)],
            actions: []
        )
    }

    @Test("Make bed each(Dave): only Dave has it")
    func makeBed() {
        let bed = Self.daily("bed", "Make bed", slots: [SlotFixture.morning], .each([Person.dave]))
        #expect(RecurrenceEngine(record: bed, today: Day.mon, openMembers: Person.everyone).lanes().map(\.assignee) == [.profile(Person.dave)])
        #expect(Self.today(Person.dave, [bed]).items(for: "bed").count == 1)
        #expect(Self.today(Person.carol, [bed]).items(for: "bed").isEmpty)
        #expect(Self.today(Person.bob, [bed]).items(for: "bed").isEmpty)
    }

    @Test("Brush teeth (Morning + Evening) each(Carol, Dave): 4 items, each ticked separately")
    func brushTeeth() {
        let teeth = Self.daily("teeth", "Brush teeth", slots: [SlotFixture.morning, SlotFixture.evening], .each([Person.carol, Person.dave]))
        #expect(RecurrenceEngine(record: teeth, today: Day.mon, openMembers: Person.everyone).lanes().count == 4)

        let ticked = TaskRecord(
            task: teeth.task, versions: teeth.versions,
            actions: [act(.complete, "teeth", slot: SlotFixture.morning, for: Person.carol, occurrence: Day.mon)]
        )
        let carol = Self.today(Person.carol, [ticked]).items(for: "teeth")
        let dave = Self.today(Person.dave, [ticked]).items(for: "teeth")
        #expect(carol.count == 2)
        #expect(dave.count == 2)
        #expect(carol.first { $0.lane.slotId == SlotFixture.morning }?.resolution == .done)
        #expect(carol.first { $0.lane.slotId == SlotFixture.evening }?.resolution == .open)
        #expect(dave.allSatisfy { $0.resolution == .open })
    }

    @Test("Empty dishwasher anyOf(Carol, Dave, Bob): one shared item; whoever ticks it closes it for everyone")
    func dishwasher() {
        let dishes = Self.daily("dishes", "Empty dishwasher", slots: [SlotFixture.anytime], .anyOf([Person.carol, Person.dave, Person.bob]))
        #expect(RecurrenceEngine(record: dishes, today: Day.mon, openMembers: Person.everyone).lanes().map(\.assignee) == [.shared])
        for viewer in [Person.carol, Person.dave, Person.bob] {
            #expect(Self.today(viewer, [dishes]).items(for: "dishes").count == 1)
        }
        #expect(Self.today(Person.alice, [dishes]).items(for: "dishes").isEmpty)

        let ticked = TaskRecord(
            task: dishes.task, versions: dishes.versions,
            actions: [act(.complete, "dishes", slot: SlotFixture.anytime, for: nil, occurrence: Day.mon, by: Person.carol)]
        )
        for viewer in [Person.carol, Person.dave, Person.bob] {
            #expect(Self.today(viewer, [ticked]).items(for: "dishes").map(\.resolution) == [.done])
        }
    }

    @Test("Change sheets anyOf, floating: one shared clock that whoever does it restarts")
    func sharedFloatingSheets() {
        let sheets = TaskRecord(
            task: householdTask("sheets", "Change sheets"),
            versions: [version("sheets", from: Day.mon, anchor: .floating, .days(every: 7, start: Day.mon), slots: [SlotFixture.anytime],
                               policy: .carryOver, assignment: .anyOf([Person.carol, Person.dave, Person.bob]), seed: Day.mon)],
            actions: [act(.complete, "sheets", slot: SlotFixture.anytime, for: nil, occurrence: Day.mon, by: Person.dave)]
        )
        let lane = Lane(taskId: "sheets", assignee: .shared, slotId: SlotFixture.anytime)
        for viewer in [Person.carol, Person.bob] {
            #expect(Self.today(viewer, [sheets]).items(for: "sheets").map(\.resolution) == [.done])
        }
        #expect(RecurrenceEngine(record: sheets, today: Day.nextSun, openMembers: Person.everyone).state(of: lane) == nil)
        #expect(RecurrenceEngine(record: sheets, today: Day.nextMon, openMembers: Person.everyone).state(of: lane)?.resolution == .open)
    }

    @Test("An unlinked profile (Dave) owns only household-scope tasks (DM-12)")
    func unlinkedOwnsOnlyHouseholdTasks() {
        let personal = personalTask("diary", "Diary", owner: Person.dave)
        #expect(personal.validate(ownerIsLinked: false) == [.unlinkedProfileOwnsPersonalTask])
        #expect(personal.validate(ownerIsLinked: true).isEmpty)
        #expect(householdTask("bed", "Make bed").validate(ownerIsLinked: false).isEmpty)
    }
}
