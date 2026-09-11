import SwiftUI

/// A two-column table, one column per player, one row per quantity.
///
/// Used both while playing and while counting so the sidebar keeps a single shape:
/// figures right-aligned in tabular digits, so columns read vertically and a total
/// can be checked against the rows above it.
public struct PlayerTable: View {
    public struct Row: Identifiable, Sendable {
        public let id: String
        public let label: String
        public let black: Double?
        public let white: Double?
        public let isTotal: Bool

        public init(_ label: String, black: Double?, white: Double?, isTotal: Bool = false) {
            self.id = label
            self.label = label
            self.black = black
            self.white = white
            self.isTotal = isTotal
        }

        public init(_ label: String, black: Int?, white: Int?) {
            self.init(label, black: black.map(Double.init), white: white.map(Double.init))
        }
    }

    public let rows: [Row]

    public init(rows: [Row]) {
        self.rows = rows
    }

    /// Number columns are fixed so the label column keeps whatever is left; letting
    /// all three share the width squeezed "Prisonniers" onto two lines.
    private static let figureWidth: CGFloat = 38

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Color.clear.frame(height: 0)
                stoneHeader(.black)
                stoneHeader(.white)
            }

            ForEach(rows) { row in
                if row.isTotal {
                    GridRow {
                        Rectangle().fill(Theme.hairline).frame(height: 0.5).gridCellColumns(3)
                    }
                }
                GridRow {
                    Text(row.label)
                        .font(.system(size: 12))
                        .foregroundStyle(row.isTotal ? Theme.primaryText : Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    figure(row.black, emphasised: row.isTotal)
                    figure(row.white, emphasised: row.isTotal)
                }
            }
        }
    }

    private func stoneHeader(_ color: PlayerColor) -> some View {
        Circle()
            .fill(Theme.stone(color))
            .strokeBorder(Theme.primaryText.opacity(color == .black ? 0.25 : 0), lineWidth: 0.5)
            .frame(width: 10, height: 10)
            .frame(width: Self.figureWidth, alignment: .trailing)
            .accessibilityLabel(Theme.name(color))
    }

    /// A right-aligned number, or a dash when the quantity does not apply to that
    /// player — Black has no komi.
    private func figure(_ value: Double?, emphasised: Bool) -> some View {
        Text(value.map(Self.format) ?? "—")
            .font(.system(size: emphasised ? 14 : 12))
            .foregroundStyle(
                value == nil
                    ? Theme.secondaryText.opacity(0.7)
                    : (emphasised ? Theme.primaryText : Theme.primaryText.opacity(0.85))
            )
            .monospacedDigit()
            .frame(width: Self.figureWidth, alignment: .trailing)
    }

    /// French decimals, and no trailing zero on whole numbers.
    public static func format(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        let text =
            rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
