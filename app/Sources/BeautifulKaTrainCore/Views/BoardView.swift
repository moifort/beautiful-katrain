import SwiftUI

/// Draws the board and reports clicks. Holds no rules and no state of its own.
public struct BoardView: View {
    public let state: GameState
    public let isInteractive: Bool
    public let onPlay: (Point) -> Void

    public init(state: GameState, isInteractive: Bool, onPlay: @escaping (Point) -> Void) {
        self.state = state
        self.isInteractive = isInteractive
        self.onPlay = onPlay
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let geometry = BoardGeometry(size: state.size, side: side)

            ZStack {
                Canvas { context, _ in
                    draw(in: &context, geometry: geometry)
                }
                .frame(width: side, height: side)
                .background(Theme.wood)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.015, style: .continuous))
                // A Canvas draws but does not take part in hit testing, so clicks are
                // caught by an explicit shape laid over it. Drawing and interaction
                // stay separate.
                .overlay {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture(coordinateSpace: .local)
                                .onEnded { tap in
                                    guard isInteractive,
                                        let point = geometry.intersection(at: tap.location)
                                    else { return }
                                    onPlay(point)
                                }
                        )
                }
                .accessibilityElement()
                .accessibilityLabel("Goban \(state.size) sur \(state.size)")
                .accessibilityValue("\(state.stones.count) pierres, coup \(state.moveNumber)")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func draw(in context: inout GraphicsContext, geometry: BoardGeometry) {
        drawGrid(in: &context, geometry: geometry)
        drawStarPoints(in: &context, geometry: geometry)
        drawStones(in: &context, geometry: geometry)
        drawLastMove(in: &context, geometry: geometry)
    }

    private func drawGrid(in context: inout GraphicsContext, geometry: BoardGeometry) {
        var path = Path()
        let last = geometry.size - 1
        for index in 0...last {
            let start = geometry.position(row: index, col: 0)
            let end = geometry.position(row: index, col: last)
            path.move(to: start)
            path.addLine(to: end)

            let top = geometry.position(row: 0, col: index)
            let bottom = geometry.position(row: last, col: index)
            path.move(to: top)
            path.addLine(to: bottom)
        }
        context.stroke(path, with: .color(Theme.gridLine), lineWidth: geometry.lineWidth)
    }

    private func drawStarPoints(in context: inout GraphicsContext, geometry: BoardGeometry) {
        for point in geometry.starPoints {
            let center = geometry.position(of: point)
            let radius = geometry.starRadius
            let rect = CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(Theme.gridLine))
        }
    }

    private func drawStones(in context: inout GraphicsContext, geometry: BoardGeometry) {
        let radius = geometry.stoneRadius
        for stone in state.stones {
            let center = geometry.position(row: stone.row, col: stone.col)
            let rect = CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(Theme.stone(stone.color)))
        }
    }

    private func drawLastMove(in context: inout GraphicsContext, geometry: BoardGeometry) {
        guard let last = state.lastMove,
            let stone = state.stones.first(where: { $0.row == last.row && $0.col == last.col })
        else { return }
        let center = geometry.position(of: last)
        let radius = geometry.stoneRadius * 0.44
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Theme.lastMoveMarker(on: stone.color)),
            lineWidth: max(0.8, geometry.stoneRadius * 0.10)
        )
    }
}
