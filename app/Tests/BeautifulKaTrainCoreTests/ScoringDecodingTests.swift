import Testing

@testable import BeautifulKaTrainCore

@Suite("Décodage de la phase de comptage")
struct ScoringDecodingTests {
    static let scoringLine = """
        {"event":"state","id":4,"size":9,"stones":[{"row":0,"col":0,"color":"W"}],\
        "to_play":"B","move_number":12,"last_move":null,\
        "captures":{"by_black":1,"by_white":0},"score_history":[],"score_lead":2.0,\
        "human_color":"B","status":"scoring","result":null,\
        "scoring":{"black":9.0,"white":6.5,"komi":6.5,"territory":{"B":8,"W":0},\
        "result":"B+2.5","points":[{"row":1,"col":1,"color":"B"}],\
        "dead_stones":[{"row":0,"col":0}]}}
        """

    private func decodeScoring() throws -> (GameState, ScoringDetail) {
        guard case .state(_, let state) = try BridgeEvent.decode(line: Self.scoringLine),
            let detail = state.scoring
        else {
            Issue.record("attendu un état de comptage")
            throw DecodingFailure.missing
        }
        return (state, detail)
    }

    enum DecodingFailure: Error { case missing }

    @Test("Le statut de comptage est reconnu")
    func status() throws {
        let (state, _) = try decodeScoring()
        #expect(state.status == .scoring)
        #expect(state.acceptsClicks)
        #expect(!state.isHumanTurn)
    }

    @Test("Le décompte arrive complet")
    func detail() throws {
        let (_, detail) = try decodeScoring()
        #expect(detail.black == 9.0)
        #expect(detail.white == 6.5)
        #expect(detail.komi == 6.5)
        #expect(detail.result == "B+2.5")
        #expect(detail.territory(for: .black) == 8)
        #expect(detail.territory(for: .white) == 0)
    }

    @Test("Les pierres mortes sont retrouvables par point")
    func deadStones() throws {
        let (_, detail) = try decodeScoring()
        #expect(detail.deadPoints == [Point(row: 0, col: 0)])
        #expect(!detail.deadPoints.contains(Point(row: 1, col: 1)))
    }

    @Test("Les points de territoire portent leur couleur")
    func territoryPoints() throws {
        let (_, detail) = try decodeScoring()
        #expect(detail.points == [TerritoryPoint(row: 1, col: 1, color: .black)])
    }

    @Test("Une partie en cours n'a pas de bloc de comptage")
    func playingHasNoScoring() throws {
        let line = """
            {"event":"state","id":null,"size":9,"stones":[],"to_play":"B","move_number":0,\
            "last_move":null,"captures":{"by_black":0,"by_white":0},"score_history":[],\
            "score_lead":null,"human_color":"B","status":"playing","result":null}
            """
        guard case .state(_, let state) = try BridgeEvent.decode(line: line) else {
            Issue.record("attendu un état")
            return
        }
        #expect(state.scoring == nil)
        #expect(state.acceptsClicks)
    }

    @Test("Une partie terminée n'accepte plus de clic")
    func finishedRejectsClicks() throws {
        let line = """
            {"event":"state","id":null,"size":9,"stones":[],"to_play":"B","move_number":40,\
            "last_move":null,"captures":{"by_black":0,"by_white":0},"score_history":[],\
            "score_lead":null,"human_color":"B","status":"finished","result":"B+2.5"}
            """
        guard case .state(_, let state) = try BridgeEvent.decode(line: line) else {
            Issue.record("attendu un état")
            return
        }
        #expect(!state.acceptsClicks)
        #expect(state.result == "B+2.5")
    }

    @Test("Les commandes de fin de partie s'encodent")
    func commands() throws {
        let toggle = String(decoding: try BridgeCommand.toggleDead(id: 1, row: 3, col: 4).encodedLine(), as: UTF8.self)
        #expect(toggle.contains("\"cmd\":\"toggle_dead\""))
        #expect(toggle.contains("\"row\":3"))

        let accept = String(decoding: try BridgeCommand.acceptScore(id: 2).encodedLine(), as: UTF8.self)
        #expect(accept.contains("\"cmd\":\"accept_score\""))

        let resume = String(decoding: try BridgeCommand.resumeGame(id: 3).encodedLine(), as: UTF8.self)
        #expect(resume.contains("\"cmd\":\"resume_game\""))
    }
}

@Suite("Mise en forme du tableau des joueurs")
struct ScoringFormatTests {
    @Test("Les décimales sont françaises")
    func frenchDecimals() {
        #expect(PlayerTable.format(27.5) == "27,5")
        #expect(PlayerTable.format(6.5) == "6,5")
    }

    @Test("Les entiers n'ont pas de décimale inutile")
    func wholeNumbers() {
        #expect(PlayerTable.format(18) == "18")
        #expect(PlayerTable.format(0) == "0")
    }

    @Test("Les scores sont arrondis au demi-point")
    func halfPoints() {
        #expect(PlayerTable.format(27.26) == "27,5")
        #expect(PlayerTable.format(27.1) == "27")
    }

    private func detail(black: Double, white: Double) -> ScoringDetail {
        ScoringDetail(
            black: black, white: white, komi: 6.5,
            territory: ["B": 8, "W": 0], prisoners: ["B": 1, "W": 0], stones: nil,
            result: "", points: [], deadStones: []
        )
    }

    @Test("Le vainqueur et l'écart se déduisent des totaux")
    func outcome() {
        let black = detail(black: 45.5, white: 18)
        #expect(black.outcome?.winner == .black)
        #expect(black.outcome?.margin == 27.5)

        let white = detail(black: 18, white: 45.5)
        #expect(white.outcome?.winner == .white)
        #expect(white.outcome?.margin == 27.5)
    }

    @Test("Une partie nulle n'a pas de vainqueur")
    func draw() {
        #expect(detail(black: 30, white: 30).outcome == nil)
    }

    @Test("Les composantes absentes sont lisibles comme telles")
    func missingComponents() {
        let counted = detail(black: 1, white: 2)
        #expect(counted.stones(for: .black) == nil)
        #expect(counted.prisoners(for: .black) == 1)
        #expect(counted.total(for: .white) == 2)
    }
}

@Suite("Lignes du tableau")
struct PlayerTableRowTests {
    @Test("Une ligne d'entiers se convertit sans perte")
    func integerRow() {
        let row = PlayerTable.Row("Prisonniers", black: 3, white: 16)
        #expect(row.black == 3)
        #expect(row.white == 16)
        #expect(!row.isTotal)
    }

    @Test("Une composante qui ne s'applique pas reste vide")
    func absentComponent() {
        let row = PlayerTable.Row("Komi", black: nil, white: 6.5)
        #expect(row.black == nil)
        #expect(row.white == 6.5)
    }

    @Test("Le libellé identifie la ligne")
    func identity() {
        #expect(PlayerTable.Row("Territoire", black: 1, white: 2).id == "Territoire")
    }
}
