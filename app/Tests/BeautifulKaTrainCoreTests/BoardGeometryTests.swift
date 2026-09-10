import CoreGraphics
import Testing

@testable import BeautifulKaTrainCore

@Suite("Géométrie du plateau")
struct BoardGeometryTests {
    let geometry = BoardGeometry(size: 19, side: 400)

    @Test("Chaque intersection se retrouve sous son propre point")
    func roundTrip() {
        for row in 0..<19 {
            for col in 0..<19 {
                let position = geometry.position(row: row, col: col)
                #expect(geometry.intersection(at: position) == Point(row: row, col: col))
            }
        }
    }

    @Test("Les quatre coins")
    func corners() {
        #expect(geometry.intersection(at: geometry.position(row: 0, col: 0)) == Point(row: 0, col: 0))
        #expect(geometry.intersection(at: geometry.position(row: 0, col: 18)) == Point(row: 0, col: 18))
        #expect(geometry.intersection(at: geometry.position(row: 18, col: 0)) == Point(row: 18, col: 0))
        #expect(geometry.intersection(at: geometry.position(row: 18, col: 18)) == Point(row: 18, col: 18))
    }

    @Test("Un clic dans la marge ne touche aucune intersection")
    func clicksInTheMargin() {
        #expect(geometry.intersection(at: CGPoint(x: 1, y: 1)) == nil)
        #expect(geometry.intersection(at: CGPoint(x: 399, y: 399)) == nil)
        #expect(geometry.intersection(at: CGPoint(x: 200, y: 2)) == nil)
    }

    @Test("Un clic hors du plateau est rejeté")
    func clicksOutsideTheBoard() {
        #expect(geometry.intersection(at: CGPoint(x: -30, y: 200)) == nil)
        #expect(geometry.intersection(at: CGPoint(x: 200, y: 900)) == nil)
    }

    @Test("Un clic légèrement décalé touche l'intersection la plus proche")
    func clicksNearAnIntersection() {
        let target = geometry.position(row: 5, col: 7)
        let nudged = CGPoint(x: target.x + geometry.step * 0.3, y: target.y - geometry.step * 0.3)
        #expect(geometry.intersection(at: nudged) == Point(row: 5, col: 7))
    }

    @Test("Un clic à mi-chemin entre deux intersections ne touche rien")
    func clicksBetweenIntersections() {
        let a = geometry.position(row: 5, col: 7)
        let between = CGPoint(x: a.x + geometry.step * 0.5, y: a.y + geometry.step * 0.5)
        #expect(geometry.intersection(at: between) == nil)
    }

    @Test("Les hoshi des tailles usuelles", arguments: [(19, 9), (13, 9), (9, 9)])
    func starPoints(size: Int, expected: Int) {
        #expect(BoardGeometry(size: size, side: 400).starPoints.count == expected)
    }

    @Test("Une taille inhabituelle n'a pas de hoshi")
    func noStarPointsOnUnusualSizes() {
        #expect(BoardGeometry(size: 11, side: 400).starPoints.isEmpty)
    }
}
