@testable import Domain

// Shared test data. The worked examples in domain model §7 use Mon 2026-09-28 to Sun 2026-10-04,
// a day start of 05:00, and Bob as the profile unless another is named.

enum Day {
    static let prevMon = LogicalDate(year: 2026, month: 9, day: 21)
    static let sun = LogicalDate(year: 2026, month: 9, day: 27)
    static let mon = LogicalDate(year: 2026, month: 9, day: 28)
    static let tue = LogicalDate(year: 2026, month: 9, day: 29)
    static let wed = LogicalDate(year: 2026, month: 9, day: 30)
    static let thu = LogicalDate(year: 2026, month: 10, day: 1)
    static let fri = LogicalDate(year: 2026, month: 10, day: 2)
    static let sat = LogicalDate(year: 2026, month: 10, day: 3)
    static let nextSun = LogicalDate(year: 2026, month: 10, day: 4)
    static let nextMon = LogicalDate(year: 2026, month: 10, day: 5)
    static let nextTue = LogicalDate(year: 2026, month: 10, day: 6)
    static let nextWed = LogicalDate(year: 2026, month: 10, day: 7)
}

enum Person {
    static let alice: ProfileID = "alice"
    static let bob: ProfileID = "bob"
    static let carol: ProfileID = "carol"
    static let dave: ProfileID = "dave"
    static let everyone: Set<ProfileID> = [alice, bob, carol, dave]
}

enum SlotFixture {
    static let home: HouseholdID = "home"
    static let morning: SlotID = "morning"
    static let afternoon: SlotID = "afternoon"
    static let evening: SlotID = "evening"
    static let anytime: SlotID = "anytime"

    static let all: [Slot] = [
        Slot(id: morning, householdId: home, name: "Morning", sortOrder: 0),
        Slot(id: afternoon, householdId: home, name: "Afternoon", sortOrder: 1),
        Slot(id: evening, householdId: home, name: "Evening", sortOrder: 2),
        Slot(id: anytime, householdId: home, name: "Anytime", sortOrder: 3, isAnytime: true),
    ]
}
