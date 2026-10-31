/// The warning level of a carried-over item (FR-05, domain model §5.7).
public enum WarningLevel: Hashable, Comparable, Sendable {
    case none, mild, strong, severe

    /// Maps r = daysOverdue / nominalPeriod to a level.
    public init(daysOverdue: Int, nominalPeriod: Double, thresholds: WarningThresholds = .default) {
        guard daysOverdue > 0 else { self = .none; return }
        let ratio = nominalPeriod > 0 ? Double(daysOverdue) / nominalPeriod : .infinity
        self = ratio < thresholds.strong ? .mild : ratio < thresholds.severe ? .strong : .severe
    }
}

/// Presentation settings: they can be tuned without touching the model.
public struct WarningThresholds: Hashable, Sendable {
    /// r at which the level becomes strong.
    public var strong: Double
    /// r at which the level becomes severe.
    public var severe: Double

    public init(strong: Double, severe: Double) {
        self.strong = strong
        self.severe = severe
    }

    public static let `default` = WarningThresholds(strong: 0.5, severe: 1)
}
