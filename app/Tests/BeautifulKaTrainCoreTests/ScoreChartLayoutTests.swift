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

@Suite("Annotation de la dernière barre")
struct ScoreChartAnnotationTests {
    @Test("Le chiffre est signé, avec une virgule")
    func label() {
        #expect(ScoreChart.label(for: 2.4) == "+2,4")
        #expect(ScoreChart.label(for: -0.3) == "\u{2212}0,3")
    }

    @Test("Une partie serrée affiche zéro sans signe")
    func closeGame() {
        #expect(ScoreChart.label(for: 0) == "0")
        #expect(ScoreChart.label(for: 0.02) == "0")
        #expect(ScoreChart.label(for: -0.04) == "0")
    }

    @Test("Le chiffre monte avec une avance et descend avec un retard")
    func offsetFollowsTheBar() {
        let half: CGFloat = 18
        let total: CGFloat = 36
        let ahead = ScoreChart.labelOffset(value: 5, scale: 5, half: half, total: total)
        let behind = ScoreChart.labelOffset(value: -5, scale: 5, half: half, total: total)
        #expect(ahead < behind)
    }

    @Test("Le chiffre reste dans le graphe aux extrêmes")
    func offsetStaysInside() {
        let total: CGFloat = 36
        for value in [-99.0, -5, 0, 5, 99] {
            let offset = ScoreChart.labelOffset(value: value, scale: 5, half: 18, total: total)
            #expect(offset >= 0)
            #expect(offset <= total - 14)
        }
    }

    @Test("Une partie nulle place le chiffre près du milieu")
    func evenGameSitsNearTheMiddle() {
        let offset = ScoreChart.labelOffset(value: 0, scale: 5, half: 18, total: 36)
        #expect(abs(offset - 11) < 6)
    }
}
