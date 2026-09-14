import Foundation

/// Vérifie, depuis l'intérieur du sandbox, que le bundle sait jouer un coup.
///
/// Lancer le python du bundle depuis un terminal ne prouverait rien : il porte
/// l'entitlement `inherit` et n'aurait alors aucun parent sandboxé dont hériter.
/// Le seul endroit d'où le test est fidèle, c'est l'application elle-même.
///
/// Invoquée par `Moyo --smoke`, elle lance le pont, joue un coup, et attend que
/// KataGo réponde. Si Metal, les modèles ou la chaîne de processus cassent sous
/// sandbox, ça casse ici.
public enum BundleSelfTest {
    public static let flag = "--smoke"

    /// Code de sortie : 0 si KataGo a répondu, 1 sinon.
    public static func run(timeout: TimeInterval = 180) -> Int32 {
        func note(_ message: String) {
            FileHandle.standardError.write("smoke: \(message)\n".data(using: .utf8)!)
        }

        guard let location = BridgeLocation.resolve() else {
            note("aucun emplacement de pont n'a pu être résolu")
            return 1
        }
        note("conteneur : \(NSHomeDirectory())")
        note("pont      : \(location.script.path)")

        let process = Process()
        process.executableURL = location.python
        process.arguments = [location.script.path]
        process.currentDirectoryURL = location.script.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment
            .merging(location.environment) { _, new in new }

        let toBridge = Pipe(), fromBridge = Pipe()
        process.standardInput = toBridge
        process.standardOutput = fromBridge
        process.standardError = FileHandle.standardError

        do { try process.run() } catch {
            note("le pont n'a pas démarré — \(error)")
            return 1
        }

        let commands = """
        {"cmd":"new_game","id":"1","size":9,"komi":5.5,"rules":"japanese","human_color":"B","ai_strategy":"ai:default"}
        {"cmd":"play","id":"2","row":4,"col":4}

        """
        toBridge.fileHandleForWriting.write(commands.data(using: .utf8)!)

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()
        var played = false

        while Date() < deadline, !played {
            let chunk = fromBridge.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = String(data: buffer[..<newline], encoding: .utf8) ?? ""
                buffer.removeSubrange(...newline)
                if line.contains("\"engine_failed\"") { note("moteur en échec : \(line.prefix(200))") }
                // Le pont n'annonce pas « l'IA a joué », il republie l'état : la
                // preuve que KataGo a répondu, c'est l'apparition d'une pierre blanche.
                if line.contains("\"color\":\"W\"") { played = true }
            }
        }

        process.terminate()
        note(played ? "OK — KataGo a joué depuis le bundle" : "ÉCHEC — aucun coup avant expiration")
        return played ? 0 : 1
    }
}
