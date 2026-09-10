import Foundation

/// Where to find the Python interpreter and the bridge script.
///
/// The milestone runs the bridge from the project's virtual environment rather than
/// embedding an interpreter in the bundle. The root is taken from the environment
/// first, then from the bundle's Info.plist, which the packaging script fills in.
public struct BridgeLocation: Sendable {
    public let python: URL
    public let script: URL
    public let logDirectory: URL

    public init(root: URL) {
        python = root.appendingPathComponent(".venv/bin/python")
        script = root.appendingPathComponent("bridge/bridge.py")
        logDirectory = URL.applicationSupportDirectory.appendingPathComponent("BeautifulKaTrain")
    }

    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> BridgeLocation? {
        if let path = environment["BEAUTIFUL_KATRAIN_ROOT"], !path.isEmpty {
            return BridgeLocation(root: URL(fileURLWithPath: path))
        }
        if let path = bundle.object(forInfoDictionaryKey: "BKTProjectRoot") as? String, !path.isEmpty {
            return BridgeLocation(root: URL(fileURLWithPath: path))
        }
        return nil
    }
}
