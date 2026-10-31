/// Who a lane belongs to: one profile, or shared (`anyOf`).
public enum LaneAssignee: Hashable, Comparable, Sendable {
    case shared
    case profile(ProfileID)
}

/// One stream of occurrences: (task, assignee-or-shared, slot). `slotId` is the slot after every remap
/// up to the engine's today (§5.10), so a remapped lane keeps one identity.
public struct Lane: Hashable, Sendable {
    public var taskId: TaskID
    public var assignee: LaneAssignee
    public var slotId: SlotID

    public init(taskId: TaskID, assignee: LaneAssignee, slotId: SlotID) {
        self.taskId = taskId
        self.assignee = assignee
        self.slotId = slotId
    }
}

public enum Resolution: Hashable, Sendable {
    case open
    case done
    case skipped
}

/// What one due date of a fixed lane looks like in history (§5.4).
public enum OccurrenceStatus: Hashable, Sendable {
    /// The lane isn't due that day.
    case notDue
    /// Due after today.
    case upcoming
    /// Today's occurrence, still open.
    case open
    case done
    case skipped
    /// markMissed, unresolved, in the past.
    case missed
    /// vanish, unresolved, in the past.
    case neutral
    /// carryOver, unresolved, in the past: part of today's carried item.
    case overdue
    /// carryOver, resolved by an action for a later occurrence (DM-03).
    case clearedByLater
}

/// What a lane shows on the engine's today.
public struct LaneState: Hashable, Sendable {
    public var lane: Lane
    /// The occurrence an action on this item targets.
    public var occurrenceDate: LogicalDate
    public var resolution: Resolution
    /// carryOver: the first unresolved due date. Floating: `nextDue`. Nil otherwise.
    public var overdueSince: LogicalDate?
    /// Never negative (DM-20).
    public var daysOverdue: Int
    public var nominalPeriod: Double
    /// Set while a snooze hides the item (§5.8).
    public var snoozedUntil: LogicalDate?

    public var isSnoozed: Bool { snoozedUntil != nil }

    /// With the default thresholds. Use `WarningLevel(daysOverdue:nominalPeriod:thresholds:)` to tune them.
    public var warning: WarningLevel {
        resolution == .open ? WarningLevel(daysOverdue: daysOverdue, nominalPeriod: nominalPeriod) : .none
    }
}
