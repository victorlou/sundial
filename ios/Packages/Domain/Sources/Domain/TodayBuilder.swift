/// One item on Today: a lane's state plus its task.
public struct TodayItem: Hashable, Sendable {
    public var task: TaskDefinition
    public var state: LaneState

    public var lane: Lane { state.lane }
    public var occurrenceDate: LogicalDate { state.occurrenceDate }
    public var resolution: Resolution { state.resolution }
    public var overdueSince: LogicalDate? { state.overdueSince }
    public var daysOverdue: Int { state.daysOverdue }
    public var nominalPeriod: Double { state.nominalPeriod }
    public var warning: WarningLevel { state.warning }
}

/// One slot's items. `slot` is nil only if the household has no Anytime slot to put misplaced lanes under.
public struct TodaySection: Hashable, Sendable {
    public var slot: Slot?
    public var items: [TodayItem]
}

/// Today, as a function (domain model §6): the viewer's personal Today.
public enum TodayBuilder {
    /// - Parameters:
    ///   - viewer: whose Today it is. They see their personal lanes, and household lanes where they're the assignee
    ///     or in the `anyOf` set.
    ///   - date: the viewer's logical date.
    ///   - tasks: every task the viewer might see, with all their versions and actions.
    ///   - slots: the household's slots, archived ones included.
    ///   - openMembers: profiles with an open membership in the household (§5.2).
    /// - Returns: non-empty sections in slot `sortOrder`, Anytime last. Items within a slot sort by task title.
    public static func build(
        viewer: ProfileID, date: LogicalDate, tasks: [TaskRecord], slots: [Slot], openMembers: Set<ProfileID>? = nil
    ) -> [TodaySection] {
        var items: [TodayItem] = []
        for record in tasks where !record.task.isArchived {
            let engine = RecurrenceEngine(record: record, today: date, openMembers: openMembers)
            let anyOf: [ProfileID] = if case .anyOf(let profiles) = engine.version(on: date)?.assignment { profiles } else { [] }
            for lane in engine.lanes() {
                let visible = switch (record.task.scope, lane.assignee) {
                case (.personal(let owner), _): owner == viewer
                case (.household, .profile(let assignee)): assignee == viewer
                case (.household, .shared): anyOf.contains(viewer)
                }
                guard visible, let state = engine.state(of: lane), !state.isSnoozed else { continue }
                items.append(TodayItem(task: record.task, state: state))
            }
        }

        // A lane whose slot is archived or missing shows under Anytime (DM-19).
        let anytime = slots.first { $0.isAnytime && !$0.isArchived } ?? slots.first(where: \.isAnytime)
        let active = Dictionary(slots.filter { !$0.isArchived && !$0.isAnytime }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var bySlot: [SlotID?: [TodayItem]] = [:]
        for item in items {
            bySlot[active[item.lane.slotId]?.id ?? anytime?.id, default: []].append(item)
        }

        let ordered = active.values.sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }.map(Optional.some) + [anytime]
        return ordered.compactMap { slot -> TodaySection? in
            guard let sectionItems = bySlot[slot?.id], !sectionItems.isEmpty else { return nil }
            let sorted = sectionItems.sorted {
                ($0.task.title, $0.task.id, $0.lane.assignee, $0.lane.slotId) < ($1.task.title, $1.task.id, $1.lane.assignee, $1.lane.slotId)
            }
            return TodaySection(slot: slot, items: sorted)
        }
    }
}
