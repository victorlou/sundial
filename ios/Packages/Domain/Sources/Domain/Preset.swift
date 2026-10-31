/// UI names for a combination of anchor and miss policy (domain model §5.6). The model has no task types.
public enum Preset: CaseIterable, Hashable, Sendable {
    case habit
    case routineChore
    case everySoOften
    case niceToDo
    case toDo

    public var anchor: Anchor {
        self == .everySoOften ? .floating : .fixed
    }

    public var missPolicy: MissPolicy {
        switch self {
        case .habit: .markMissed
        case .routineChore, .everySoOften, .toDo: .carryOver
        case .niceToDo: .vanish
        }
    }

    /// To-do uses the `once` pattern; the others repeat.
    public var isOnce: Bool { self == .toDo }

    /// The preset a rule matches, if any (the user can adjust any preset).
    public static func matching(anchor: Anchor, missPolicy: MissPolicy, pattern: Pattern) -> Preset? {
        let isOnce = if case .once = pattern { true } else { false }
        return allCases.first { $0.anchor == anchor && $0.missPolicy == missPolicy && $0.isOnce == isOnce }
    }
}
