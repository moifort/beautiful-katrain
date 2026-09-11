import CoreGraphics
import Testing

@testable import BeautifulKaTrainCore

@Suite("Agrégation du graphe de score")
struct ScoreChartLayoutTests {
    /// The sidebar chart is about this wide in points.
    let width = 152.0

    @Test("Une partie courte garde une barre par coup")
    func shortGame() {
        let scores = Dictionary(uniqueKeysWithValues: (0...4).map { ($0, Double($0)) })
        let bars = ScoreChartLayout.bars(scores: scores, upTo: 4, width: width)
        #expect(bars.count == 5)
        #expect(bars.map(\.value) == [0, 1, 2, 3, 4])
    }

    @Test("Quarante-sept coups tiennent en barres lisibles")
    func mediumGame() {
        let scores = Dictionary(uniqueKeysWithValues: (0...47).map { ($0, 1.0) })
        let bars = ScoreChartLayout.bars(scores: scores, upTo: 47, width: width)
        #expect(bars.count <= ScoreChartLayout.maximumBarCount(width: width))
        #expect(bars.count == 24)
    }

    @Test("Une partie longue reste dans la largeur disponible")
    func longGame() {
        let scores = Dictionary(uniqueKeysWithValues: (0...299).map { ($0, 2.0) })
        let bars = ScoreChartLayout.bars(scores: scores, upTo: 299, width: width)
        #expect(bars.count <= ScoreChartLayout.maximumBarCount(width: width))
        #expect(bars.allSatisfy { $0.value == 2.0 })
    }

    @Test("La dernière barre est celle du coup courant, et elle seule")
    func currentBar() {
        let bars = ScoreChartLayout.bars(scores: [0: 1], upTo: 10, width: width)
        #expect(bars.last?.isCurrent == true)
        #expect(bars.dropLast().allSatisfy { !$0.isCurrent })
    }

    @Test("Un coup non analysé laisse un trou, pas un zéro")
    func missingAnalysisIsAHole() {
        let bars = ScoreChartLayout.bars(scores: [:], upTo: 3, width: width)
        #expect(bars.allSatisfy { $0.value == nil })
    }

    @Test("Un groupe partiellement analysé moyenne ce qu'il a")
    func partialGroup() {
        let scores = Dictionary(uniqueKeysWithValues: (0...95).map { ($0, 4.0) })
        let bars = ScoreChartLayout.bars(scores: scores, upTo: 95, width: width)
        #expect(bars.allSatisfy { $0.value == 4.0 })
    }

    @Test("L'échelle ne descend pas sous son plancher")
    func scaleFloor() {
        let small = ScoreChartLayout.bars(scores: [0: 0.2], upTo: 0, width: width)
        #expect(ScoreChartLayout.scale(for: small) == ScoreChartLayout.minimumScale)
    }

    @Test("L'échelle suit un écart important")
    func scaleFollowsPeak() {
        let wide = ScoreChartLayout.bars(scores: [0: -32.0], upTo: 0, width: width)
        #expect(ScoreChartLayout.scale(for: wide) == 32)
    }

    @Test("Un plateau vide sans coup joué donne une seule barre")
    func firstMove() {
        #expect(ScoreChartLayout.bars(scores: [:], upTo: 0, width: width).count == 1)
    }
}

@Suite("Mise en forme du chiffre de score")
struct ScoreLabelTests {
    @Test("Le chiffre est nu, sans signe : la couleur porte le sens")
    func label() {
        #expect(ScoreChart.label(for: 2.4) == "2,4")
        #expect(ScoreChart.label(for: -0.3) == "0,3")
    }

    @Test("Une avance et un retard de même ampleur s'écrivent pareil")
    func signIsNotWritten() {
        #expect(ScoreChart.label(for: 7.5) == ScoreChart.label(for: -7.5))
    }

    @Test("Une partie serrée affiche zéro sans signe")
    func closeGame() {
        #expect(ScoreChart.label(for: 0) == "0")
        #expect(ScoreChart.label(for: 0.02) == "0")
        #expect(ScoreChart.label(for: -0.04) == "0")
    }

    @Test("Les grands écarts restent lisibles")
    func wideMargins() {
        #expect(ScoreChart.label(for: 132.5) == "132,5")
        #expect(ScoreChart.label(for: -7) == "7,0")
    }
}

@Suite("Position du chiffre sur la dernière barre")
struct ScoreLabelPlacementTests {
    let half: CGFloat = 20
    let total: CGFloat = 40

    @Test("Une avance place le chiffre au-dessus de la barre")
    func aheadSitsAbove() {
        let offset = ScoreChart.labelOffset(value: 4, scale: 5, half: half, total: total)
        #expect(offset < half)
    }

    @Test("Un retard place le chiffre sous la barre")
    func behindSitsBelow() {
        let offset = ScoreChart.labelOffset(value: -4, scale: 5, half: half, total: total)
        #expect(offset > half)
    }

    @Test("Plus l'avance est grande, plus le chiffre monte")
    func offsetFollowsTheBar() {
        let small = ScoreChart.labelOffset(value: 1, scale: 5, half: half, total: total)
        let large = ScoreChart.labelOffset(value: 5, scale: 5, half: half, total: total)
        #expect(large < small)
    }

    @Test("Le chiffre ne sort jamais du graphe")
    func staysInside() {
        for value in [-500.0, -5, -0.1, 0, 0.1, 5, 500] {
            let offset = ScoreChart.labelOffset(value: value, scale: 5, half: half, total: total)
            #expect(offset >= 0)
            #expect(offset <= total - 12)
        }
    }

    @Test("Une partie serrée garde le chiffre près du milieu")
    func closeGameSitsNearTheMiddle() {
        let offset = ScoreChart.labelOffset(value: 0, scale: 5, half: half, total: total)
        #expect(abs(offset - half) < half)
    }
}

@Suite("Position horizontale du chiffre")
struct ScoreLabelHorizontalTests {
    let total: CGFloat = 170

    @Test("En début de partie le chiffre suit la barre, à gauche")
    func followsTheFirstBar() {
        #expect(ScoreChart.labelX(barCount: 1, total: total) == 0)
    }

    @Test("Le chiffre avance avec les coups")
    func movesRightAsTheGameGoes() {
        let early = ScoreChart.labelX(barCount: 3, total: total)
        let later = ScoreChart.labelX(barCount: 10, total: total)
        #expect(early < later)
    }

    @Test("Un graphe plein cale le chiffre au bord droit")
    func fullChartPinsToTheRight() {
        #expect(ScoreChart.labelX(barCount: 40, total: total) == total - 32)
    }

    @Test("Le chiffre ne sort jamais du graphe")
    func staysInside() {
        for count in [0, 1, 5, 27, 200] {
            let x = ScoreChart.labelX(barCount: count, total: total)
            #expect(x >= 0)
            #expect(x <= total - 32)
        }
    }
}
