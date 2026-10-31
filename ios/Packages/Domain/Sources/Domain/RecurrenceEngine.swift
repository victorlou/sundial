/// The recurrence rules of domain model §5 for one task, as seen on one logical date.
/// Pure: everything it knows comes from the task record, the open memberships, and `today`.
public struct RecurrenceEngine: Sendable {
    public let record: TaskRecord
    public let today: LogicalDate
    /// Profiles with an open membership in the task's household, which filters `each` lanes (§5.2).
    /// Nil means no filter, which is right for personal tasks.
    public let openMembers: Set<ProfileID>?

    /// Sorted by `effectiveFrom`; for two versions on the same date the later one in the input wins.
    let versions: [RuleVersion]
    /// The lanes each version contains, in slot order, ignoring membership.
    let versionLanes: [[Lane]]
    /// Remap versions in effect by today, in order.
    let remaps: [RuleVersion]
    /// Unrevoked actions by lane.
    let actionsByLane: [Lane: [OccurrenceAction]]

    public init(record: TaskRecord, today: LogicalDate, openMembers: Set<ProfileID>? = nil) {
        self.record = record
        self.today = today
        self.openMembers = openMembers

        var byDate: [LogicalDate: RuleVersion] = [:]
        for version in record.versions where version.taskId == record.task.id {
            byDate[version.effectiveFrom] = version
        }
        let versions = byDate.values.sorted { $0.effectiveFrom < $1.effectiveFrom }
        let remaps = versions.filter { $0.slotMap != nil && $0.effectiveFrom <= today }
        self.versions = versions
        self.remaps = remaps

        let owner: ProfileID? = if case .personal(let owner) = record.task.scope { owner } else { nil }
        versionLanes = versions.map { version in
            var lanes: [Lane] = []
            for slot in version.slotIds {
                let slotId = Self.canonical(slot, remaps: remaps, after: version.effectiveFrom)
                let assignees: [LaneAssignee] = switch version.assignment {
                case .personal: owner.map { [.profile($0)] } ?? []
                case .each(let profiles): profiles.map { .profile($0) }
                case .anyOf: [.shared]
                }
                for assignee in assignees {
                    let lane = Lane(taskId: record.task.id, assignee: assignee, slotId: slotId)
                    if !lanes.contains(lane) { lanes.append(lane) }
                }
            }
            return lanes
        }

        var actionsByLane: [Lane: [OccurrenceAction]] = [:]
        for action in record.actions where action.taskId == record.task.id && !action.isRevoked {
            let lane = Lane(
                taskId: action.taskId,
                assignee: action.assigneeProfileId.map { .profile($0) } ?? .shared,
                // Every remap applies, so a tick recorded under an old slot ID after the remap still lands in the lane.
                slotId: Self.canonical(action.slotId, remaps: remaps, after: nil)
            )
            actionsByLane[lane, default: []].append(action)
        }
        self.actionsByLane = actionsByLane
    }

    /// Carries a slot across the remaps after `date` (all of them if nil), in order (§5.10).
    static func canonical(_ slot: SlotID, remaps: [RuleVersion], after date: LogicalDate?) -> SlotID {
        var slot = slot
        for remap in remaps where date.map({ remap.effectiveFrom > $0 }) ?? true {
            if let mapped = remap.slotMap?[slot] { slot = mapped }
        }
        return slot
    }

    // MARK: Versions and lanes (§2.7, §5.2)

    func versionIndex(on date: LogicalDate) -> Int? {
        versions.lastIndex { $0.effectiveFrom <= date }
    }

    /// The version in effect on `date`.
    public func version(on date: LogicalDate) -> RuleVersion? {
        versionIndex(on: date).map { versions[$0] }
    }

    /// The lanes that exist in today's version (§5.2). Only these appear in Today.
    public func lanes() -> [Lane] {
        guard let index = versionIndex(on: today) else { return [] }
        let checksMembership = if case .each = versions[index].assignment { true } else { false }
        return versionLanes[index].filter { lane in
            guard checksMembership, let openMembers, case .profile(let profile) = lane.assignee else { return true }
            return openMembers.contains(profile)
        }
    }

    // MARK: Due dates (§5.1, §5.3)

    /// Whether a fixed lane is due on `date`: the version in effect generates the date and still contains the lane.
    public func isDue(_ lane: Lane, on date: LogicalDate) -> Bool {
        guard let index = versionIndex(on: date) else { return false }
        return generates(index, date, lane)
    }

    func generates(_ index: Int, _ date: LogicalDate, _ lane: Lane) -> Bool {
        let version = versions[index]
        guard version.anchor == .fixed, versionLanes[index].contains(lane) else { return false }
        switch version.pattern {
        case .once(let onDate?):
            return date == onDate
        case .once(nil):
            // Due at the start of the lane's run of undated `once` versions, so an edit doesn't add a due date.
            guard date == version.effectiveFrom else { return false }
            guard index > 0 else { return true }
            let previous = versions[index - 1]
            let continuesRun = previous.anchor == .fixed && previous.pattern == .once(date: nil) && versionLanes[index - 1].contains(lane)
            return !continuesRun
        case .days(let every, let start):
            return every > 0 && date >= start && (date - start) % every == 0
        case .weeks(let every, let weekdays, let start):
            guard every > 0, date >= start, weekdays.contains(date.weekday) else { return false }
            return ((date.startOfWeek - start.startOfWeek) / 7) % every == 0
        case .months(let every, let monthDay, let start):
            guard every > 0, date >= start, let monthDay, date.months(since: start) % every == 0 else { return false }
            return monthDay.matches(date)
        }
    }

    // MARK: History (§5.4)

    /// How one date of a fixed lane reads in history.
    public func status(of lane: Lane, on date: LogicalDate) -> OccurrenceStatus {
        guard let index = versionIndex(on: date), generates(index, date, lane) else { return .notDue }
        if let resolution = exactResolution(lane, date) { return resolution == .done ? .done : .skipped }
        if date > today { return .upcoming }
        switch versions[index].missPolicy {
        case .vanish:
            return date == today ? .open : .neutral
        case .markMissed:
            return date == today ? .open : .missed
        case .carryOver:
            if let latest = latestResolvedOccurrence(lane), latest >= date { return .clearedByLater }
            return date == today ? .open : .overdue
        }
    }

    // MARK: Today's state of a lane (§5.4, §5.5, §5.8)

    /// What the lane shows today, or nil if nothing. Includes snoozed items, marked with `snoozedUntil`.
    public func state(of lane: Lane) -> LaneState? {
        guard let index = versionIndex(on: today), lanes().contains(lane) else { return nil }
        let version = versions[index]
        let nominalPeriod = version.pattern.nominalPeriod

        func item(_ occurrence: LogicalDate, _ resolution: Resolution, overdueSince: LogicalDate? = nil) -> LaneState {
            LaneState(
                lane: lane, occurrenceDate: occurrence, resolution: resolution, overdueSince: overdueSince,
                daysOverdue: overdueSince.map { max(0, today - $0) } ?? 0, nominalPeriod: nominalPeriod, snoozedUntil: nil
            )
        }

        switch (version.anchor, version.missPolicy) {
        case (.floating, _):
            if let nextDue = nextFloatingDue(lane, version), nextDue <= today {
                return snoozing(item(nextDue, .open, overdueSince: nextDue), version)
            }
        case (.fixed, .vanish), (.fixed, .markMissed):
            if generates(index, today, lane) {
                return item(today, exactResolution(lane, today) ?? .open)
            }
        case (.fixed, .carryOver):
            if let backlog = carryOverBacklog(lane) {
                return snoozing(item(backlog.latest, .open, overdueSince: backlog.first), version)
            }
        }

        // Items resolved by actions acted on today stay visible, checked (§6).
        let resolvedToday = resolving(lane).filter { $0.actedOn == today }
        guard let latest = resolvedToday.max(by: { $0.occurrenceDate < $1.occurrenceDate }) else { return nil }
        return item(latest.occurrenceDate, resolvedToday.contains { $0.kind == .complete } ? .done : .skipped)
    }

    /// The unrevoked complete and skip actions of a lane.
    func resolving(_ lane: Lane) -> [OccurrenceAction] {
        (actionsByLane[lane] ?? []).filter(\.kind.isResolving)
    }

    /// done or skipped if an action targets exactly this occurrence. A completion wins over a skip.
    func exactResolution(_ lane: Lane, _ date: LogicalDate) -> Resolution? {
        let actions = resolving(lane).filter { $0.occurrenceDate == date }
        if actions.contains(where: { $0.kind == .complete }) { return .done }
        return actions.isEmpty ? nil : .skipped
    }

    func latestResolvedOccurrence(_ lane: Lane) -> LogicalDate? {
        resolving(lane).map(\.occurrenceDate).max()
    }

    /// The unresolved carryOver due dates up to today: the first and the latest (§5.4).
    /// Each date follows the policy of the version in effect on it, so earlier vanish or markMissed dates aren't carried.
    func carryOverBacklog(_ lane: Lane) -> (first: LogicalDate, latest: LogicalDate)? {
        guard let start = versions.first?.effectiveFrom else { return nil }
        let lower = max(start, (latestResolvedOccurrence(lane) ?? start - 1) + 1)
        guard lower <= today else { return nil }

        func carried(_ date: LogicalDate) -> Bool {
            guard let index = versionIndex(on: date) else { return false }
            return versions[index].missPolicy == .carryOver && generates(index, date, lane)
        }
        var latest = today
        while latest >= lower, !carried(latest) { latest = latest - 1 }
        guard latest >= lower else { return nil }
        var first = lower
        while !carried(first) { first = first + 1 }
        return (first, latest)
    }

    /// `lastResolution + interval(today's version)`, or the seed with no history (§5.5). Skips count too.
    func nextFloatingDue(_ lane: Lane, _ version: RuleVersion) -> LogicalDate? {
        guard let last = resolving(lane).map(\.actedOn).max() else { return version.floatingSeed }
        return version.pattern.floatingNext(after: last)
    }

    /// Marks an open item as hidden by the latest unrevoked snooze, if one applies (§5.8).
    func snoozing(_ state: LaneState, _ version: RuleVersion) -> LaneState {
        guard version.allowsSnooze else { return state }
        let snoozes = (actionsByLane[state.lane] ?? []).filter { $0.kind == .snooze && $0.snoozeUntil != nil }
        guard let latest = snoozes.max(by: { ($0.actedOn, $0.snoozeUntil!, $0.id) < ($1.actedOn, $1.snoozeUntil!, $1.id) }),
              let until = latest.snoozeUntil, today < until,
              !resolving(state.lane).contains(where: { $0.actedOn >= latest.actedOn })
        else { return state }
        var hidden = state
        hidden.snoozedUntil = until
        return hidden
    }
}

extension RuleVersion {
    /// Snooze is only for carryOver and floating lanes (DM-05).
    public var allowsSnooze: Bool { anchor == .floating || missPolicy == .carryOver }
}

extension MonthDay {
    func matches(_ date: LogicalDate) -> Bool {
        let length = LogicalDate.daysInMonth(year: date.year, month: date.month)
        switch self {
        case .day(let k):
            return date.day == min(k, length)
        case .weekday(let ordinal, let weekday):
            guard date.weekday == weekday else { return false }
            return switch ordinal {
            case .first: date.day <= 7
            case .second: (8...14).contains(date.day)
            case .third: (15...21).contains(date.day)
            case .fourth: (22...28).contains(date.day)
            case .last: date.day + 7 > length
            }
        }
    }
}

extension Pattern {
    /// §5.7: the period the warning ratio divides by.
    public var nominalPeriod: Double {
        switch self {
        case .once: 7
        case .days(let every, _): Double(every)
        case .weeks(let every, let weekdays, _): 7 * Double(every) / Double(max(1, weekdays.count))
        case .months(let every, _, _): 30 * Double(every)
        }
    }

    /// The next floating due date after `date`. Months are calendar months, clamped (DM-06).
    func floatingNext(after date: LogicalDate) -> LogicalDate? {
        switch self {
        case .once: nil
        case .days(let every, _): date + every
        case .weeks(let every, _, _): date + 7 * every
        case .months(let every, _, _): date.adding(months: every)
        }
    }
}
