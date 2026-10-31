/// The backfill window (DM-07).
public enum BackfillWindow {
    public static let days = 7
}

public enum RuleValidationError: Hashable, Sendable {
    /// `effectiveFrom` must be today or later: the past is never rewritten (FR-18).
    case effectiveFromInPast
    case noSlots
    case duplicateSlots
    /// DM-04.
    case floatingNeedsOneSlot
    /// DM-04.
    case floatingNeedsCarryOver
    /// The first due date when there's no history.
    case floatingNeedsSeed
    /// Floating allows only every-n days, weeks, or months.
    case patternNotAllowedForFloating
    case intervalMustBePositive
    case noWeekdays
    case missingMonthDay
    case invalidMonthDay
    case onceDateBeforeEffectiveFrom
    /// `personal` goes with personal scope; `each` and `anyOf` with household scope.
    case assignmentDoesNotMatchScope
    case emptyAssignment
    case duplicateAssignees
}

extension RuleVersion {
    /// Checks a version before it's written. `today` is the writer's logical date.
    public func validate(scope: Scope, today: LogicalDate) -> [RuleValidationError] {
        var errors: [RuleValidationError] = []
        if effectiveFrom < today { errors.append(.effectiveFromInPast) }
        if slotIds.isEmpty {
            errors.append(.noSlots)
        } else if Set(slotIds).count != slotIds.count {
            errors.append(.duplicateSlots)
        }

        switch pattern {
        case .days(let every, _), .weeks(let every, _, _), .months(let every, _, _):
            if every < 1 { errors.append(.intervalMustBePositive) }
        case .once:
            break
        }

        switch anchor {
        case .floating:
            if slotIds.count > 1 { errors.append(.floatingNeedsOneSlot) }
            if missPolicy != .carryOver { errors.append(.floatingNeedsCarryOver) }
            if floatingSeed == nil { errors.append(.floatingNeedsSeed) }
            let allowed = switch pattern {
            case .once: false
            case .days: true
            case .weeks(_, let weekdays, _): weekdays.isEmpty
            case .months(_, let monthDay, _): monthDay == nil
            }
            if !allowed { errors.append(.patternNotAllowedForFloating) }
        case .fixed:
            switch pattern {
            case .once(let date?) where date < effectiveFrom:
                errors.append(.onceDateBeforeEffectiveFrom)
            case .weeks(_, let weekdays, _) where weekdays.isEmpty:
                errors.append(.noWeekdays)
            case .months(_, nil, _):
                errors.append(.missingMonthDay)
            case .months(_, .day(let k)?, _) where !(1...31).contains(k):
                errors.append(.invalidMonthDay)
            default:
                break
            }
        }

        switch (assignment, scope) {
        case (.personal, .personal):
            break
        case (.each(let profiles), .household), (.anyOf(let profiles), .household):
            if profiles.isEmpty {
                errors.append(.emptyAssignment)
            } else if Set(profiles).count != profiles.count {
                errors.append(.duplicateAssignees)
            }
        default:
            errors.append(.assignmentDoesNotMatchScope)
        }
        return errors
    }
}


public enum TaskValidationError: Hashable, Sendable {
    /// DM-12.
    case unlinkedProfileOwnsPersonalTask
}

extension TaskDefinition {
    /// `ownerIsLinked`: whether the owner of a personal task has an account.
    public func validate(ownerIsLinked: Bool) -> [TaskValidationError] {
        if case .personal = scope, !ownerIsLinked { return [.unlinkedProfileOwnsPersonalTask] }
        return []
    }
}

public enum ActionValidationError: Hashable, Sendable {
    /// `actedOn`, or the occurrence on a vanish or markMissed lane, is more than 7 days back (DM-07).
    case outsideBackfillWindow
    /// Dated after this device's today. Actions from other devices may be; this device doesn't write them.
    case inFuture
    /// DM-05.
    case snoozeNotAllowed
    case snoozeUntilNotAfterActedOn
}

extension RecurrenceEngine {
    /// Checks an action this device is about to write, against the engine's today.
    public func validate(_ action: OccurrenceAction) -> [ActionValidationError] {
        var errors: [ActionValidationError] = []
        let windowStart = today - BackfillWindow.days
        let exactMatchOccurrence = version(on: action.occurrenceDate).map { $0.anchor == .fixed && $0.missPolicy != .carryOver } ?? false

        if action.actedOn > today || action.occurrenceDate > today {
            errors.append(.inFuture)
        } else if action.actedOn < windowStart || (exactMatchOccurrence && action.occurrenceDate < windowStart) {
            // carryOver and floating items can target an older occurrence: the latest unresolved one.
            errors.append(.outsideBackfillWindow)
        }

        if action.kind == .snooze {
            if let version = version(on: today), !version.allowsSnooze { errors.append(.snoozeNotAllowed) }
            if action.snoozeUntil.map({ $0 <= action.actedOn }) ?? true { errors.append(.snoozeUntilNotAfterActedOn) }
        }
        return errors
    }
}
