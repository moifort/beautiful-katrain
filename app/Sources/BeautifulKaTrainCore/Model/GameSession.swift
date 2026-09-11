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

    /// What the player chose last, carried across launches.
    ///
    /// These are preferences, not state: at startup they are sent to the bridge,
    /// which then owns the truth. Each mode keeps its own setting, so switching from
    /// the human model to a period style and back finds the rank where it was left.
    public struct Settings: Equatable, Sendable, Codable {
        public var size: Int
        public var komi: Double
        public var rules: String
        public var humanColor: PlayerColor
        public var aiStrategy: String
        public var aiSettingValues: [String: Double]

        public init(
            size: Int = 19,
            komi: Double = 6.5,
            rules: String = "japanese",
            humanColor: PlayerColor = .black,
            aiStrategy: String = "ai:human",
            aiSettingValues: [String: Double] = [:]
        ) {
            self.size = size
            self.komi = komi
            self.rules = rules
            self.humanColor = humanColor
            self.aiStrategy = aiStrategy
            self.aiSettingValues = aiSettingValues
        }

        public func value(for mode: AIMode) -> Double? {
            aiSettingValues[mode.id]
        }

        public mutating func setValue(_ value: Double, for mode: AIMode) {
            aiSettingValues[mode.id] = value
        }
    }

    public private(set) var phase: Phase = .starting
    public private(set) var state: GameState?
    public private(set) var engineDescription: String?
    public private(set) var lastErrorMessage: String?
    public var settings = Settings()

    /// AI modes this installation offers, in KaTrain's own recommended order.
    public private(set) var availableStrategies: [String] = []
    /// Current settings per mode, as the bridge reports them at startup.
    public private(set) var bridgeSettings: [String: [String: SettingValue]] = [:]

    public var modes: [AIMode] { availableStrategies.map(AIMode.mode(for:)) }

    /// The mode actually in force, taken from the last state rather than from our
    /// own settings, so the interface reflects the bridge and not the reverse.
    public var currentMode: AIMode {
        AIMode.mode(for: state?.aiStrategy ?? settings.aiStrategy)
    }

    /// Value of a mode's main setting: what the bridge last reported, else the
    /// startup value, else the middle of the control's range.
    public func settingValue(for mode: AIMode) -> Double? {
        guard let setting = mode.setting else { return nil }
        if state?.aiStrategy == mode.id, let value = state?.aiSettings?[setting.key]?.doubleValue {
            return value
        }
        if let remembered = settings.value(for: mode) {
            return remembered
        }
        if let value = bridgeSettings[mode.id]?[setting.key]?.doubleValue {
            return value
        }
        return (setting.range.lowerBound + setting.range.upperBound) / 2
    }

    /// Switches the opponent mid-game; it applies from its next move.
    public func setAI(mode: AIMode, value: Double?) {
        settings.aiStrategy = mode.id
        var payload: [String: Double] = [:]
        if let setting = mode.setting, let value {
            payload[setting.key] = value
            settings.setValue(value, for: mode)
        }
        store.save(settings)
        bridge.send(.setAI(id: nextID(), strategy: mode.id, settings: payload))
    }

    public let thinking = ThinkingIndicator()

    /// Score lead per move number, filled in as analyses come back.
    public private(set) var scoreByMove: [Int: Double] = [:]

    private let bridge: BridgeProcess
    private let store: SettingsStore
    private var nextCommandID = 1
    private var eventTask: Task<Void, Never>?

    public init(bridge: BridgeProcess = BridgeProcess(), store: SettingsStore = SettingsStore()) {
        self.bridge = bridge
        self.store = store
        self.settings = store.load() ?? Settings()
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
        case .ready(let katago, let model, let strategies, let settings):
            phase = .running
            engineDescription = model.map { URL(fileURLWithPath: $0).lastPathComponent } ?? katago
            availableStrategies = strategies
            bridgeSettings = settings
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
        if newState.status != .playing { thinking.ended() }
    }

    // -- commands ------------------------------------------------------------

    private func nextID() -> Int {
        defer { nextCommandID += 1 }
        return nextCommandID
    }

    public func newGame() {
        store.save(settings)
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
                aiSettings: newGameSettings
            )
        )
    }

    /// The main setting of the chosen mode, if it has one. Everything else keeps the
    /// values from the shared KaTrain configuration.
    private var newGameSettings: [String: Double] {
        let mode = AIMode.mode(for: settings.aiStrategy)
        guard let setting = mode.setting, let value = settingValue(for: mode) else { return [:] }
        return [setting.key: value]
    }

    public func play(row: Int, col: Int) {
        guard canAct else { return }
        bridge.send(.play(id: nextID(), row: row, col: col))
    }

    public func passTurn() {
        guard canAct else { return }
        bridge.send(.pass(id: nextID()))
    }

    /// Flips the group under a point between dead and alive, while counting.
    public func toggleDead(row: Int, col: Int) {
        guard state?.status == .scoring else { return }
        bridge.send(.toggleDead(id: nextID(), row: row, col: col))
    }

    public func acceptScore() {
        guard state?.status == .scoring else { return }
        bridge.send(.acceptScore(id: nextID()))
    }

    /// Takes back the last pass and carries on playing.
    public func resumeGame() {
        guard state?.status == .scoring else { return }
        bridge.send(.resumeGame(id: nextID()))
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
