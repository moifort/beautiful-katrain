import SwiftUI

/// The score graph: capsule bars above and below a midline, one hue, two weights.
///
/// Read from the human player's side: above the middle they are ahead and the bar
/// is white, below it they are behind and it turns red. No axis, no midline, no
/// legend — and no separate readout either: the current value is written at the tip
/// of the last bar, where the eye already is.
public struct ScoreChart: View {
    public let scores: [Int: Double]
    public let moveNumber: Int
    /// Value to write at the tip of the last bar. Nil leaves the chart bare.
    public let annotation: Double?
    public let height: CGFloat

    /// Room reserved to the right of the bars for the figure.
    private static let labelWidth: CGFloat = 40
    private static let labelHeight: CGFloat = 14

    public init(
        scores: [Int: Double],
        moveNumber: Int,
        annotation: Double? = nil,
        height: CGFloat = 36
    ) {
        self.scores = scores
        self.moveNumber = moveNumber
        self.annotation = annotation
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            let reserved = annotation == nil ? 0 : Self.labelWidth
            let chartWidth = max(1, proxy.size.width - reserved)
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
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(
                            annotation >= 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent
                        )
                        .frame(width: Self.labelWidth, height: Self.labelHeight, alignment: .trailing)
                        .offset(
                            x: chartWidth,
                            y: Self.labelOffset(
                                value: lastValue(of: bars),
                                scale: scale,
                                half: half,
                                total: proxy.size.height
                            )
                        )
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("Graphe de l'avantage au score")
    }

    private func lastValue(of bars: [ScoreChartLayout.Bar]) -> Double {
        bars.last?.value ?? annotation ?? 0
    }

    /// Vertical position of the figure: level with the tip of the last bar, kept
    /// inside the chart so it never clips at the extremes.
    static func labelOffset(value: Double, scale: Double, half: CGFloat, total: CGFloat) -> CGFloat {
        let magnitude = CGFloat(min(1, abs(value) / scale)) * half
        let length = max(ScoreChartLayout.minimumBarWidth, magnitude)
        let tip = value >= 0 ? half - length : half + length
        let centred = tip - labelHeight / 2
        return min(max(0, centred), max(0, total - labelHeight))
    }

    /// A signed figure, with a true minus sign and a French decimal comma.
    static func label(for value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "0" }
        let magnitude = String(format: "%.1f", abs(rounded)).replacingOccurrences(of: ".", with: ",")
        return (rounded > 0 ? "+" : "\u{2212}") + magnitude
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
