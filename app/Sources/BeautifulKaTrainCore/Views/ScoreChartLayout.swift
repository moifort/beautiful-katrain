import CoreGraphics

/// Groups per-move scores into the bars a chart of a given width can actually show.
///
/// Below a certain width bars stop reading as bars and turn into hairs, so moves are
/// aggregated instead — the way Health switches from hours to days as the range
/// grows.
public enum ScoreChartLayout {
    public struct Bar: Equatable, Sendable {
        /// Mean lead over the moves in this group, or nil when none of them has been
        /// analysed yet. Nil bars are left out rather than drawn at zero.
        public let value: Double?
        public let isCurrent: Bool
    }

    public static let minimumBarWidth: CGFloat = 3.5
    public static let spacing: CGFloat = 2.7

    public static func maximumBarCount(width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minimumBarWidth + spacing)))
    }

    public static func bars(scores: [Int: Double], upTo moveNumber: Int, width: CGFloat) -> [Bar] {
        guard moveNumber >= 0 else { return [] }
        let moveCount = moveNumber + 1
        let capacity = maximumBarCount(width: width)
        let groupSize = max(1, Int((Double(moveCount) / Double(capacity)).rounded(.up)))

        var bars: [Bar] = []
        var start = 0
        while start < moveCount {
            let end = min(start + groupSize, moveCount)
            let values = (start..<end).compactMap { scores[$0] }
            let mean = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            bars.append(Bar(value: mean, isCurrent: end == moveCount))
            start = end
        }
        return bars
    }

    /// Half-height of the chart in score points, so small swings stay legible while
    /// a blowout still fits.
    ///
    /// The floor is deliberately low: openings are decided by fractions of a point,
    /// and a floor of five would flatten the first thirty moves into a straight line.
    public static let minimumScale: Double = 2.5

    public static func scale(for bars: [Bar]) -> Double {
        let peak = bars.compactMap { $0.value.map(abs) }.max() ?? 0
        return max(minimumScale, peak)
    }
}
