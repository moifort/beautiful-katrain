import Testing

@testable import BeautifulKaTrainCore

@Suite("Affichage du score en attendant l'analyse")
struct ScoreReadoutTests {
    @Test("La dernière valeur connue tient pendant que l'analyse rattrape")
    func holdsLastKnownValue() {
        let scores: [Int: Double] = [0: 0.5, 1: 1.2, 2: -0.4]
        #expect(GameSession.latestLead(in: scores, upTo: 4) == -0.4)
        #expect(GameSession.latestLead(in: scores, upTo: 2) == -0.4)
        #expect(GameSession.latestLead(in: scores, upTo: 1) == 1.2)
    }

    @Test("Aucune analyse encore reçue : rien à afficher")
    func nothingKnownYet() {
        #expect(GameSession.latestLead(in: [:], upTo: 7) == nil)
    }

    @Test("Les coups annulés ne ressuscitent pas")
    func doesNotReachPastTheCurrentMove() {
        #expect(GameSession.latestLead(in: [5: 3.0], upTo: 2) == nil)
    }

    @Test("Le coup zéro compte comme une valeur connue")
    func rootCounts() {
        #expect(GameSession.latestLead(in: [0: 0.0], upTo: 3) == 0.0)
    }
}
