/// Streaks and averages (domain model §5.9).
extension RecurrenceEngine {
    /// Consecutive due dates of the task's markMissed lanes for `assignee`, grouped across slots,
    /// going back from yesterday. All-skipped dates neither break nor add. Today adds once done and never breaks.
    public func streak(for assignee: LaneAssignee) -> Int {
        guard let start = versions.first?.effectiveFrom else { return 0 }

        enum Day { case notDue, counts, neutral, breaks }
        func result(_ date: LogicalDate) -> Day {
            guard let index = versionIndex(on: date), versions[index].missPolicy == .markMissed else { return .notDue }
            let due = versionLanes[index].filter { $0.assignee == assignee && generates(index, date, $0) }
            guard !due.isEmpty else { return .notDue }
            let resolutions = due.map { exactResolution($0, date) }
            if resolutions.contains(nil) { return .breaks }
            return resolutions.allSatisfy { $0 == .skipped } ? .neutral : .counts
        }

        var count = result(today) == .counts ? 1 : 0
        var date = today - 1
        while date >= start {
            switch result(date) {
            case .counts: count += 1
            case .breaks: return count
            case .notDue, .neutral: break
            }
            date = date - 1
        }
        return count
    }

    /// The mean gap in days between the last 5 distinct completion dates (`actedOn`). Skips are left out.
    /// Nil with fewer than two dates.
    public func averageInterval(of lane: Lane) -> Double? {
        let dates = Set((actionsByLane[lane] ?? []).filter { $0.kind == .complete }.map(\.actedOn)).sorted().suffix(5)
        guard let first = dates.first, let last = dates.last, dates.count >= 2 else { return nil }
        return Double(last - first) / Double(dates.count - 1)
    }
}
