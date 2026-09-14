import Testing

@testable import MoyoCore

@Suite("Ouverture scriptée pour les captures d'écran")
struct DemoScriptTests {
    @Test("Sans l'option, rien ne se déclenche")
    func absentByDefault() {
        #expect(DemoScript.isRequested(in: ["/Applications/Moyo.app/Contents/MacOS/Moyo"]) == false)
    }

    @Test("L'option déclenche la démo")
    func presentWhenAsked() {
        #expect(DemoScript.isRequested(in: ["Moyo", "--demo"]))
    }

    @Test("Tous les coups tombent sur le goban")
    func movesAreOnTheBoard() {
        // Le script vise un 19×19 : un coup hors plage serait rejeté par le pont
        // et la démo attendrait indéfiniment une réponse qui ne viendrait pas.
        #expect(DemoScript.moves.allSatisfy { (0..<19).contains($0.row) && (0..<19).contains($0.col) })
    }

    @Test("Aucun coup n'est joué deux fois")
    func movesAreDistinct() {
        let played = Set(DemoScript.moves.map { "\($0.row),\($0.col)" })
        #expect(played.count == DemoScript.moves.count)
    }
}
