import Foundation
import Testing

@testable import MoyoCore

@Suite("Lecture d'un fichier SGF")
struct SGFImportTests {
    @Test("Un enregistrement UTF-8 revient tel quel")
    func utf8() throws {
        let text = "(;GM[1]FF[4]SZ[19]PB[Sébastien];B[qd])"
        let record = try read(Data(text.utf8), named: "partie.sgf")
        #expect(record.contents == text)
        #expect(record.name == "partie.sgf")
    }

    @Test("Un enregistrement Latin-1 est décodé sans être refusé")
    func latin1() throws {
        let text = "(;GM[1]FF[4]SZ[19]PB[Sébastien];B[qd])"
        let data = try #require(text.data(using: .isoLatin1))
        // Ces octets ne sont pas de l'UTF-8 valide : la reprise doit s'en charger.
        #expect(String(data: data, encoding: .utf8) == nil)
        let record = try read(data, named: "vieux.sgf")
        #expect(record.contents.contains("PB["))
        #expect(record.contents.contains(";B[qd]"))
    }

    @Test("Latin-1 accepte n'importe quel octet, donc rien n'est indécodable")
    func neverUndecodable() throws {
        let data = Data([0x28, 0x3B, 0xFF, 0xFE, 0x80, 0x29])
        #expect(SGFImport.decode(data) != nil)
    }

    @Test("Un fichier vide est signalé comme tel")
    func empty() throws {
        #expect(throws: SGFImport.Failure.empty("vide.sgf")) {
            _ = try read(Data("   \n".utf8), named: "vide.sgf")
        }
    }

    @Test("Un fichier absent n'est pas lisible")
    func missing() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("absent-\(UUID().uuidString).sgf")
        #expect(throws: SGFImport.Failure.notReadable(url.lastPathComponent)) {
            _ = try SGFImport.read(url)
        }
    }

    /// Écrit les octets dans un fichier temporaire, puisque c'est un fichier que
    /// l'import sait lire — et non des données en mémoire. Le dossier porte l'UUID,
    /// pas le fichier : son nom voyage jusqu'au titre de la fenêtre.
    private func read(_ data: Data, named name: String) throws -> SGFImport.Record {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return try SGFImport.read(url)
    }
}
