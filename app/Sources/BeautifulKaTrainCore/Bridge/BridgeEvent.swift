import Foundation

public enum PlayerColor: String, Codable, Sendable, Hashable {
    case black = "B"
    case white = "W"

    public var opponent: PlayerColor { self == .black ? .white : .black }
}

public struct Point: Codable, Sendable, Hashable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct Stone: Codable, Sendable, Hashable {
    public let row: Int
    public let col: Int
    public let color: PlayerColor

    public var point: Point { Point(row: row, col: col) }
}

public struct Captures: Codable, Sendable, Hashable {
    public let byBlack: Int
    public let byWhite: Int

    public init(byBlack: Int, byWhite: Int) {
        self.byBlack = byBlack
        self.byWhite = byWhite
    }
}

public enum GameStatus: String, Codable, Sendable {
    case playing
    /// Both players have passed; the dead stones are being agreed on.
    case scoring
    case finished
}

public struct TerritoryPoint: Codable, Sendable, Hashable {
    public let row: Int
    public let col: Int
    public let color: PlayerColor

    public var point: Point { Point(row: row, col: col) }
}

/// The count as it stands, recomputed by the bridge on every change.
public struct ScoringDetail: Codable, Sendable {
    public let black: Double
    public let white: Double
    public let komi: Double
    public let territory: [String: Int]
    public let result: String
    public let points: [TerritoryPoint]
    public let deadStones: [Point]

    public func territory(for color: PlayerColor) -> Int {
        territory[color.rawValue] ?? 0
    }

    public var deadPoints: Set<Point> { Set(deadStones) }
}

/// The whole board state, as the bridge sees it. The app never derives it.
public struct GameState: Codable, Sendable {
    public let size: Int
    public let stones: [Stone]
    public let toPlay: PlayerColor
    public let moveNumber: Int
    public let lastMove: Point?
    public let captures: Captures
    public let scoreHistory: [Double?]
    public let scoreLead: Double?
    public let humanColor: PlayerColor
    public let status: GameStatus
    public let result: String?
    public let scoring: ScoringDetail?

    public var isHumanTurn: Bool { status == .playing && toPlay == humanColor }

    /// Points the player can act on: play a stone, or mark a group dead.
    public var acceptsClicks: Bool { status == .playing || status == .scoring }
}

public enum BridgeEvent: Sendable {
    case ready(katago: String?, model: String?)
    case state(id: Int?, GameState)
    case thinking(Bool)
    case score(moveNumber: Int, scoreLead: Double)
    case failure(id: Int?, code: String, message: String)
    case engineFailed(message: String)

    /// Events the bridge may add later. Ignoring them keeps an older app from
    /// choking on a newer bridge.
    case unknown(String)
}

extension BridgeEvent: Decodable {
    private enum Keys: String, CodingKey {
        case event, id, katago, model, value, moveNumber, scoreLead, code, message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let name = try container.decode(String.self, forKey: .event)
        let id = try container.decodeIfPresent(Int.self, forKey: .id)

        switch name {
        case "ready":
            self = .ready(
                katago: try container.decodeIfPresent(String.self, forKey: .katago),
                model: try container.decodeIfPresent(String.self, forKey: .model)
            )
        case "state":
            self = .state(id: id, try GameState(from: decoder))
        case "thinking":
            self = .thinking(try container.decode(Bool.self, forKey: .value))
        case "score":
            self = .score(
                moveNumber: try container.decode(Int.self, forKey: .moveNumber),
                scoreLead: try container.decode(Double.self, forKey: .scoreLead)
            )
        case "error":
            self = .failure(
                id: id,
                code: try container.decode(String.self, forKey: .code),
                message: try container.decode(String.self, forKey: .message)
            )
        case "engine_failed":
            self = .engineFailed(message: try container.decode(String.self, forKey: .message))
        default:
            self = .unknown(name)
        }
    }

    public static func decode(line: String) throws -> BridgeEvent {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BridgeEvent.self, from: Data(line.utf8))
    }
}
