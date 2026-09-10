import Foundation

/// Holds the last state the bridge sent and forwards the player's intentions to it.
///
/// Nothing here decides whether a move is legal, whose turn it is, or what the score
/// is. Every one of those answers arrives as an event.
@MainActor
@Observable
public final class GameSession {
    public enum Phase: Equatable {
        case starting
        case running
        case failed(String)
    }

    public struct Settings: Equatable, Sendable {
        public var size: Int
        public var komi: Double
        public var rules: String
        public var humanColor: PlayerColor
        public var aiStrategy: String
        public var humanRankKyu: Int

        public init(
            size: Int = 19,
            komi: Double = 6.5,
            rules: String = "japanese",
            humanColor: PlayerColor = .black,
            aiStrategy: String = "ai:human",
            humanRankKyu: Int = 8
        ) {
            self.size = size
            self.komi = komi
            self.rules = rules
            self.humanColor = humanColor
            self.aiStrategy = aiStrategy
            self.humanRankKyu = humanRankKyu
        }

        /// What to call the opponent on screen. The model filename is accurate but
        /// unreadable, so it stays in the log.
        public var opponentName: String {
            switch aiStrategy {
            case "ai:human": "KataGo humanlike"
            case "ai:default": "KataGo"
            case "ai:handicap": "KataGo handicap"
            case "ai:policy": "KataGo policy"
            case "ai:scoreloss": "KataGo score loss"
            default: aiStrategy.replacingOccurrences(of: "ai:", with: "KataGo ")
            }
        }

        /// Only the human-like model is rated in kyu.
        public var showsRank: Bool { aiStrategy == "ai:human" }
    }

    public private(set) var phase: Phase = .starting
    public private(set) var state: GameState?
    public private(set) var engineDescription: String?
    public private(set) var lastErrorMessage: String?
    public var settings = Settings()

    public let thinking = ThinkingIndicator()

    /// Score lead per move number, filled in as analyses come back.
    public private(set) var scoreByMove: [Int: Double] = [:]

    private let bridge: BridgeProcess
    private var nextCommandID = 1
    private var eventTask: Task<Void, Never>?

    public init(bridge: BridgeProcess = BridgeProcess()) {
        self.bridge = bridge
    }

    // -- lifecycle -----------------------------------------------------------

    public func start() {
        guard let location = BridgeLocation.resolve() else {
            phase = .failed(
                "Emplacement du projet inconnu. Définissez BEAUTIFUL_KATRAIN_ROOT ou reconstruisez l'application."
            )
            return
        }
        do {
            let events = try bridge.start(
                python: location.python,
                script: location.script,
                logDirectory: location.logDirectory
            )
            eventTask = Task { [weak self] in
                for await event in events {
                    self?.handle(event)
                }
                self?.bridgeDidStop()
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func stop() {
        eventTask?.cancel()
        bridge.stop()
    }

    private func bridgeDidStop() {
        guard case .failed = phase else {
            phase = .failed("Le pont s'est arrêté. La partie en cours est perdue.")
            return
        }
    }

    // -- events --------------------------------------------------------------

    private func handle(_ event: BridgeEvent) {
        switch event {
        case .ready(let katago, let model):
            phase = .running
            engineDescription = model.map { URL(fileURLWithPath: $0).lastPathComponent } ?? katago
            newGame()

        case .state(_, let newState):
            apply(newState)

        case .thinking(let value):
            value ? thinking.began() : thinking.ended()

        case .score(let moveNumber, let scoreLead):
            scoreByMove[moveNumber] = scoreLead

        case .failure(_, let code, let message):
            // An illegal move needs no announcement: the stone simply does not land.
            if code != "illegal_move" {
                lastErrorMessage = message
            }

        case .engineFailed(let message):
            phase = .failed(message)

        case .unknown:
            break
        }
    }

    private func apply(_ newState: GameState) {
        // Moves beyond the current one no longer exist, typically after an undo.
        scoreByMove = scoreByMove.filter { $0.key <= newState.moveNumber }
        for (index, score) in newState.scoreHistory.enumerated() {
            if let score { scoreByMove[index] = score }
        }
        state = newState
        if newState.status == .finished { thinking.ended() }
    }

    // -- commands ------------------------------------------------------------

    private func nextID() -> Int {
        defer { nextCommandID += 1 }
        return nextCommandID
    }

    public func newGame() {
        scoreByMove.removeAll()
        state = nil
        lastErrorMessage = nil
        bridge.send(
            .newGame(
                id: nextID(),
                size: settings.size,
                komi: settings.komi,
                rules: settings.rules,
                humanColor: settings.humanColor,
                aiStrategy: settings.aiStrategy,
                aiSettings: ["human_kyu_rank": Double(settings.humanRankKyu)]
            )
        )
    }

    public func play(row: Int, col: Int) {
        guard canAct else { return }
        bridge.send(.play(id: nextID(), row: row, col: col))
    }

    public func passTurn() {
        guard canAct else { return }
        bridge.send(.pass(id: nextID()))
    }

    public func undo() {
        guard state != nil, state?.status == .playing else { return }
        bridge.send(.undo(id: nextID()))
    }

    public func resign() {
        guard state != nil, state?.status == .playing else { return }
        bridge.send(.resign(id: nextID()))
    }

    /// Scores flipped to the human player's side: positive means they are ahead.
    ///
    /// The bridge reports the lead from Black's point of view, which would make the
    /// colours lie whenever the player takes White.
    public var scoresFromPlayerSide: [Int: Double] {
        let sign: Double = (state?.humanColor ?? .black) == .black ? 1 : -1
        return scoreByMove.mapValues { $0 * sign }
    }

    /// The most recent lead known at or before a given move.
    ///
    /// Analyses arrive a move or two behind the stones. Reading only the current move
    /// would blank the figure out every time the AI plays, so the last known value
    /// holds until a fresher one arrives.
    nonisolated static func latestLead(in scores: [Int: Double], upTo moveNumber: Int) -> Double? {
        scores.keys.filter { $0 <= moveNumber }.max().flatMap { scores[$0] }
    }

    /// The player's current lead, held over while KataGo catches up.
    public var currentLead: Double? {
        guard let state else { return nil }
        let sign: Double = state.humanColor == .black ? 1 : -1
        let lead =
            scoreByMove[state.moveNumber]
            ?? state.scoreLead
            ?? Self.latestLead(in: scoreByMove, upTo: state.moveNumber)
        return lead.map { $0 * sign }
    }

    /// True when the player may act: a game is running and it is their turn.
    public var canAct: Bool {
        phase == .running && (state?.isHumanTurn ?? false)
    }
}
