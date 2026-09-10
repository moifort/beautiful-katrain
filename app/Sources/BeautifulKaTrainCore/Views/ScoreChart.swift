import SwiftUI

/// The score graph: capsule bars above and below a midline, one hue, two weights.
///
/// Read from the human player's side: above the middle they are ahead and the bar
/// is white, below it they are behind and it turns red. No axis, no midline, no
/// legend — the figure above the chart carries the value, the chart only the shape.
public struct ScoreChart: View {
    public let scores: [Int: Double]
    public let moveNumber: Int
    public let height: CGFloat

    public init(scores: [Int: Double], moveNumber: Int, height: CGFloat = 50) {
        self.scores = scores
        self.moveNumber = moveNumber
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            let bars = ScoreChartLayout.bars(scores: scores, upTo: moveNumber, width: proxy.size.width)
            let scale = ScoreChartLayout.scale(for: bars)
            let half = proxy.size.height / 2

            HStack(alignment: .center, spacing: ScoreChartLayout.spacing) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    BarShape(bar: bar, scale: scale, half: half)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .frame(height: height)
        .accessibilityLabel("Graphe de l'avantage au score")
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
