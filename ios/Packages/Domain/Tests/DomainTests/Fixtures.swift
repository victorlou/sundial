@testable import Domain

// Builders for tasks, rule versions, and actions, and helpers for reading engine and Today results.

func personalTask(_ id: TaskID, _ title: String, owner: ProfileID = Person.bob) -> TaskDefinition {
    TaskDefinition(id: id, scope: .personal(owner), title: title, createdByProfileId: owner)
}

func householdTask(_ id: TaskID, _ title: String) -> TaskDefinition {
    TaskDefinition(id: id, scope: .household(SlotFixture.home), title: title, createdByProfileId: Person.bob)
}

func version(
    _ task: TaskID,
    from effectiveFrom: LogicalDate,
    anchor: Anchor = .fixed,
    _ pattern: Pattern,
    slots: [SlotID],
    policy: MissPolicy,
    assignment: Assignment = .personal,
    seed: LogicalDate? = nil,
    slotMap: [SlotID: SlotID]? = nil
) -> RuleVersion {
    RuleVersion(
        // Stands in for UUIDv5(taskId, effectiveFrom), which Data generates.
        id: RuleVersionID(rawValue: "\(task.rawValue)@\(effectiveFrom)"),
        taskId: task,
        effectiveFrom: effectiveFrom,
        anchor: anchor,
        pattern: pattern,
        slotIds: slots,
        slotMap: slotMap,
        missPolicy: policy,
        assignment: assignment,
        floatingSeed: seed
    )
}

func act(
    _ kind: ActionKind,
    _ task: TaskID,
    slot: SlotID,
    for assignee: ProfileID? = Person.bob,
    occurrence: LogicalDate,
    actedOn: LogicalDate? = nil,
    by actor: ProfileID? = nil,
    snoozeUntil: LogicalDate? = nil,
    revoked: Bool = false,
    id: String? = nil
) -> OccurrenceAction {
    let acted = actedOn ?? occurrence
    return OccurrenceAction(
        id: ActionID(rawValue: id ?? "\(kind)-\(task.rawValue)-\(slot.rawValue)-\(assignee?.rawValue ?? "shared")-\(occurrence)-\(acted)"),
        taskId: task,
        kind: kind,
        slotId: slot,
        assigneeProfileId: assignee,
        occurrenceDate: occurrence,
        actedOn: acted,
        actorProfileId: actor ?? assignee ?? Person.bob,
        snoozeUntil: snoozeUntil,
        isRevoked: revoked
    )
}

extension RecurrenceEngine {
    /// The lane in today's version for this assignee and slot. Fails the test by returning a lane that matches nothing if absent.
    func lane(_ assignee: LaneAssignee, _ slot: SlotID) -> Lane {
        lanes().first { $0.assignee == assignee && $0.slotId == slot }
            ?? Lane(taskId: record.task.id, assignee: assignee, slotId: slot)
    }
}

extension Array where Element == TodaySection {
    var allItems: [TodayItem] { flatMap(\.items) }

    func items(for task: TaskID) -> [TodayItem] { allItems.filter { $0.task.id == task } }

    func section(of task: TaskID) -> Slot? {
        first { $0.items.contains { $0.task.id == task } }?.slot
    }
}
