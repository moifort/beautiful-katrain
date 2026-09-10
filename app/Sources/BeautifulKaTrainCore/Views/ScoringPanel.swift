import SwiftUI

/// The count, shown while the two players agree on the dead stones.
///
/// Every figure here comes from the bridge, recomputed after each change. The panel
/// adds nothing up on its own.
public struct ScoringPanel: View {
    public let detail: ScoringDetail
    public let onResume: () -> Void
    public let onAccept: () -> Void

    public init(
        detail: ScoringDetail,
        onResume: @escaping () -> Void,
        onAccept: @escaping () -> Void
    ) {
        self.detail = detail
        self.onResume = onResume
        self.onAccept = onAccept
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comptage")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.primaryText)

            Text("Cliquez sur un groupe pour le déclarer mort ou vivant.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Theme.hairline).frame(height: 0.5)

            VStack(spacing: 6) {
                row(color: .black, total: detail.black)
                row(color: .white, total: detail.white)
            }

            Rectangle().fill(Theme.hairline).frame(height: 0.5)

            HStack {
                Text(outcome)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                Button("Reprendre la partie", action: onResume)
                    .buttonStyle(.glass)
                Button("Accepter le score", action: onAccept)
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    private func row(color: PlayerColor, total: Double) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.stone(color))
                .frame(width: 11, height: 11)
            Text(Theme.name(color))
                .font(.system(size: 13))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
            Spacer(minLength: 0)
            Text(breakdown(for: color))
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
            Text(format(total))
                .font(.system(size: 14))
                .foregroundStyle(Theme.primaryText)
                .monospacedDigit()
        }
    }

    /// Where each side's points come from, so the total can be checked at a glance.
    private func breakdown(for color: PlayerColor) -> String {
        let territory = detail.territory(for: color)
        if color == .white, detail.komi != 0 {
            return "\(territory) + komi \(format(detail.komi))"
        }
        return "\(territory) de territoire"
    }

    private var outcome: String {
        switch detail.result {
        case "Draw": "Partie nulle"
        default:
            detail.result.hasPrefix("B+")
                ? "Noir gagne de \(detail.result.dropFirst(2))"
                : "Blanc gagne de \(detail.result.dropFirst(2))"
        }
    }

    private func format(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
