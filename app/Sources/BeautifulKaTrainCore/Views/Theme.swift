import SwiftUI

/// The app's own palette. It does not follow the system appearance: a board reads
/// better on a dark surface, and glass over a light background turns milky.
public enum Theme {
    public static let windowBackground = Color(red: 0.133, green: 0.122, blue: 0.106)
    public static let wood = Color(red: 0.874, green: 0.745, blue: 0.545)
    public static let gridLine = Color(red: 0.290, green: 0.220, blue: 0.137)
    public static let blackStone = Color(red: 0.102, green: 0.090, blue: 0.078)
    public static let whiteStone = Color(red: 0.969, green: 0.961, blue: 0.945)

    /// Lifts the sidebar slightly off the window background so its glass reads as
    /// glass rather than as a flat panel.
    public static let sidebarVeil = Color.white.opacity(0.06)

    public static let primaryText = Color.white
    public static let secondaryText = Color.white.opacity(0.55)
    public static let hairline = Color.white.opacity(0.14)

    /// The chart is read from the human player's side: white when they are ahead,
    /// red when they are behind, the way Stocks colours a move against you.
    public static let chartAhead = Color.white.opacity(0.85)
    public static let chartBehind = Color(red: 0.847, green: 0.271, blue: 0.247).opacity(0.85)
    public static let chartAheadCurrent = Color.white
    public static let chartBehindCurrent = Color(red: 0.847, green: 0.271, blue: 0.247)

    public static func stone(_ color: PlayerColor) -> Color {
        color == .black ? blackStone : whiteStone
    }

    /// A stone agreed to be dead is not removed, it fades: the player must still be
    /// able to see what they are agreeing to.
    public static let deadStoneOpacity: Double = 0.28

    /// Marks the last move by contrast with the stone it sits on, rather than with a
    /// colour of its own.
    public static func lastMoveMarker(on stone: PlayerColor) -> Color {
        stone == .black ? whiteStone : blackStone
    }

    public static func name(_ color: PlayerColor) -> String {
        color == .black ? "Noir" : "Blanc"
    }
}
