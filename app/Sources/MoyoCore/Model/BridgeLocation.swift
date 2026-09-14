import Foundation

/// Où trouver l'interpréteur Python, le pont, et ce dont le moteur a besoin.
///
/// L'application distribuée est autonome : interpréteur, `katago`, modèles et
/// configuration vivent tous dans le bundle, et le sandbox interdirait de toute
/// façon d'aller les chercher ailleurs. `environment` est la façon dont le bundle
/// les désigne au pont.
///
/// En développement, `MOYO_DEV_ROOT` fait tourner le pont depuis le dépôt et
/// n'impose aucun chemin : le pont lit `~/.katrain` comme il l'a toujours fait.
public struct BridgeLocation: Sendable {
    public let python: URL
    public let script: URL
    public let logDirectory: URL
    /// Chemins moteur imposés au pont. Vide en développement.
    public let environment: [String: String]

    private static var logs: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Moyo")
    }

    /// Depuis le `Contents` d'un bundle. Tous les chemins lui sont internes.
    public static func bundled(contents: URL) -> BridgeLocation {
        let resources = contents.appendingPathComponent("Resources")
        let helpers = contents.appendingPathComponent("Helpers")
        let models = resources.appendingPathComponent("models")
        return BridgeLocation(
            python: resources.appendingPathComponent("python/bin/python3.13"),
            script: resources.appendingPathComponent("bridge/bridge.py"),
            logDirectory: logs,
            environment: [
                "MOYO_KATAGO": helpers.appendingPathComponent("katago").path,
                "MOYO_MODEL": models.appendingPathComponent("play.bin.gz").path,
                "MOYO_HUMAN_MODEL": models.appendingPathComponent("human.bin.gz").path,
                "MOYO_CONFIG": resources.appendingPathComponent("analysis_config.cfg").path,
            ]
        )
    }

    /// Depuis le dépôt, pour le développement. N'impose rien au moteur.
    public static func development(root: URL) -> BridgeLocation {
        BridgeLocation(
            python: root.appendingPathComponent(".venv/bin/python"),
            script: root.appendingPathComponent("bridge/bridge.py"),
            logDirectory: logs,
            environment: [:]
        )
    }

    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleContents: URL? = Bundle.main.bundleURL.appendingPathComponent("Contents")
    ) -> BridgeLocation? {
        if let root = environment["MOYO_DEV_ROOT"], !root.isEmpty {
            return .development(root: URL(fileURLWithPath: root))
        }
        return bundleContents.map(BridgeLocation.bundled)
    }
}
