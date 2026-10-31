/// A typed row ID. Domain imports nothing, so IDs are the UUID strings Data stores, wrapped by entity.
public struct EntityID<Entity>: Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum ProfileTag {}
public enum HouseholdTag {}

public typealias ProfileID = EntityID<ProfileTag>
public typealias HouseholdID = EntityID<HouseholdTag>
public typealias SlotID = EntityID<Slot>
public typealias TaskID = EntityID<TaskDefinition>
public typealias RuleVersionID = EntityID<RuleVersion>
public typealias ActionID = EntityID<OccurrenceAction>
