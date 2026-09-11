import Foundation

/// Remembers the player's choices across launches.
///
/// Kept in the app's own defaults rather than in `~/.katrain/config.json`: that file
/// belongs to KaTrain too, and changing an opponent here should not quietly rewrite
/// its configuration.
/// `@unchecked` because UserDefaults is documented as thread-safe but is not
/// annotated Sendable; the store itself holds no mutable state of its own.
public struct SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "game.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> GameSession.Settings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        // A stored shape from an older version is discarded rather than fought with:
        // losing a preference is cheaper than refusing to start.
        return try? JSONDecoder().decode(GameSession.Settings.self, from: data)
    }

    public func save(_ settings: GameSession.Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
