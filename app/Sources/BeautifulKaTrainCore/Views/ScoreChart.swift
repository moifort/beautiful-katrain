import SwiftUI

/// The score graph: capsule bars above and below a midline, one hue, two weights.
///
/// Read from the human player's side: above the middle they are ahead and the bar
/// is white, below it they are behind and it turns red. No axis, no midline, no
/// legend — the current value is written small just past the last bar.
public struct ScoreChart: View {
    public let scores: [Int: Double]
    public let moveNumber: Int
    /// Value to write next to the last bar. Nil leaves the chart bare.
    public let annotation: Double?
    public let height: CGFloat

    private static let labelHeight: CGFloat = 12
    /// Wide enough for the longest figure a game can produce, e.g. "132,5".
    static let labelWidth: CGFloat = 32
    /// Breathing room between the last bar and the figure.
    static let labelGap: CGFloat = 4

    public init(
        scores: [Int: Double],
        moveNumber: Int,
        annotation: Double? = nil,
        height: CGFloat = 40
    ) {
        self.scores = scores
        self.moveNumber = moveNumber
        self.annotation = annotation
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            // The bars stop short of the right edge so the figure always has room of
            // its own; drawn over them it was unreadable.
            let chartWidth = annotation == nil
                ? proxy.size.width
                : max(1, proxy.size.width - Self.labelWidth - Self.labelGap)
            let bars = ScoreChartLayout.bars(scores: scores, upTo: moveNumber, width: chartWidth)
            let scale = ScoreChartLayout.scale(for: bars)
            let half = proxy.size.height / 2

            ZStack(alignment: .topLeading) {
                HStack(alignment: .center, spacing: ScoreChartLayout.spacing) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        BarShape(bar: bar, scale: scale, half: half)
                    }
                }
                .frame(width: chartWidth, height: proxy.size.height, alignment: .leading)

                if let annotation {
                    Text(Self.label(for: annotation))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(
                            annotation >= 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent
                        )
                        .frame(width: Self.labelWidth, height: Self.labelHeight, alignment: .leading)
                        .offset(
                            x: Self.labelX(barCount: bars.count, total: proxy.size.width),
                            y: Self.labelOffset(
                                value: bars.last?.value ?? annotation,
                                scale: scale,
                                half: half,
                                total: proxy.size.height
                            )
                        )
                        .animation(.smooth(duration: 0.3), value: annotation)
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("Graphe de l'avantage au score")
    }

    /// Just past the right edge of the last bar, never over it.
    static func labelX(barCount: Int, total: CGFloat) -> CGFloat {
        let step = ScoreChartLayout.minimumBarWidth + ScoreChartLayout.spacing
        let rightEdge = CGFloat(max(0, barCount - 1)) * step + ScoreChartLayout.minimumBarWidth
        return min(max(0, rightEdge + labelGap), max(0, total - labelWidth))
    }

    /// Level with the tip of the last bar, kept inside the chart.
    static func labelOffset(value: Double, scale: Double, half: CGFloat, total: CGFloat) -> CGFloat {
        let magnitude = CGFloat(min(1, abs(value) / scale)) * half
        let length = max(ScoreChartLayout.minimumBarWidth, magnitude)
        let tip = value >= 0 ? half - length : half + length
        return min(max(0, tip - labelHeight / 2), max(0, total - labelHeight))
    }

    /// The bare magnitude, with a French decimal comma. No sign: the colour already
    /// says which way it goes — white ahead, red behind — and the bar says it twice.
    public static func label(for value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "0" }
        return String(format: "%.1f", abs(rounded)).replacingOccurrences(of: ".", with: ",")
    }

    /// One bar, split into the half above the midline and the half below it, so a
    /// positive value grows upward from the line and a negative one downward.
    private struct BarShape: View {
        let bar: ScoreChartLayout.Bar
        let scale: Double
        let half: CGFloat

        private var value: Double { bar.value ?? 0 }

        /// Positive means the human player is ahead, so the bar grows upward.
        private var isAhead: Bool { value >= 0 }

        private var length: CGFloat {
            let magnitude = CGFloat(min(1, abs(value) / scale)) * half
            return max(ScoreChartLayout.minimumBarWidth, magnitude)
        }

        private var color: Color {
            if bar.isCurrent { return isAhead ? Theme.chartAheadCurrent : Theme.chartBehindCurrent }
            return isAhead ? Theme.chartAhead : Theme.chartBehind
        }

        var body: some View {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Color.clear
                    if isAhead { capsule }
                }
                .frame(height: half)

                ZStack(alignment: .top) {
                    Color.clear
                    if !isAhead { capsule }
                }
                .frame(height: half)
            }
            .frame(width: ScoreChartLayout.minimumBarWidth)
            .opacity(bar.value == nil ? 0 : 1)
            .animation(.smooth(duration: 0.3), value: length)
        }

        private var capsule: some View {
            Capsule().fill(color).frame(width: ScoreChartLayout.minimumBarWidth, height: length)
        }
    }
}
