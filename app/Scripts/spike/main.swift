// Sonde de la phase 0 : prouver que le pont Python et KataGo tournent depuis
// l'intérieur d'un bundle signé et sandboxé.
//
// Elle lance le pont, demande une partie, joue un coup, et attend que KataGo
// réponde. Si KataGo ne peut pas atteindre le GPU sous sandbox, ça casse ici.

import Foundation

// Surtout pas argv[0] : il peut être relatif, et le sandbox place le répertoire
// courant dans le conteneur, où le bundle n'est évidemment pas.
let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
let resources = contents.appendingPathComponent("Resources")
let helpers = contents.appendingPathComponent("Helpers")

FileHandle.standardError.write("sonde: conteneur HOME = \(NSHomeDirectory())\n".data(using: .utf8)!)

let process = Process()
process.executableURL = resources.appendingPathComponent("python/bin/python3.13")
process.arguments = [resources.appendingPathComponent("bridge/bridge.py").path]
process.environment = [
    "PATH": "/usr/bin:/bin",
    "HOME": NSHomeDirectory(),
    "MOYO_KATAGO": helpers.appendingPathComponent("katago").path,
    "MOYO_MODEL": resources.appendingPathComponent("models/play.bin.gz").path,
    "MOYO_HUMAN_MODEL": resources.appendingPathComponent("models/human.bin.gz").path,
    "MOYO_CONFIG": resources.appendingPathComponent("analysis_config.cfg").path,
]

let toBridge = Pipe(), fromBridge = Pipe()
process.standardInput = toBridge
process.standardOutput = fromBridge
process.standardError = FileHandle.standardError

do { try process.run() } catch {
    FileHandle.standardError.write("sonde: impossible de lancer le pont — \(error)\n".data(using: .utf8)!)
    exit(2)
}

let commands = """
{"cmd":"new_game","id":"1","size":9,"komi":5.5,"rules":"japanese","human_color":"B","ai_strategy":"ai:default"}
{"cmd":"play","id":"2","row":4,"col":4}

"""
toBridge.fileHandleForWriting.write(commands.data(using: .utf8)!)

// KataGo doit charger un réseau de 93 Mo et initialiser Metal : laissons-lui du temps.
let deadline = Date().addingTimeInterval(180)
var buffer = Data()
var sawAIMove = false

while Date() < deadline, !sawAIMove {
    let chunk = fromBridge.fileHandleForReading.availableData
    if chunk.isEmpty { break }
    buffer.append(chunk)
    while let newline = buffer.firstIndex(of: 0x0A) {
        let line = String(data: buffer[..<newline], encoding: .utf8) ?? ""
        buffer.removeSubrange(...newline)
        FileHandle.standardError.write("evenement: \(line.prefix(200))\n".data(using: .utf8)!)
        // Le pont n'annonce pas « l'IA a joué » : il republie l'état. La preuve
        // que KataGo a répondu, c'est l'apparition d'une pierre blanche.
        if line.contains("\"color\":\"W\"") { sawAIMove = true }
        if line.contains("\"error\"") { FileHandle.standardError.write("sonde: le pont a renvoye une erreur\n".data(using: .utf8)!) }
    }
}

process.terminate()
if sawAIMove {
    FileHandle.standardError.write("SONDE OK: KataGo a joue un coup depuis le bundle sandboxe\n".data(using: .utf8)!)
    exit(0)
}
FileHandle.standardError.write("SONDE ECHEC: aucun coup de KataGo avant expiration\n".data(using: .utf8)!)
exit(1)
