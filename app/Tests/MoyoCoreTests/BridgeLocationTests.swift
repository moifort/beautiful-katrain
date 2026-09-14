import Foundation
import Testing

@testable import MoyoCore

@Suite("Où le pont et le moteur sont trouvés")
struct BridgeLocationTests {
    private let contents = URL(fileURLWithPath: "/Applications/Moyo.app/Contents")
    private let projet = URL(fileURLWithPath: "/Users/x/Code/moyo-go")

    @Test("Dans le bundle, tout est interne")
    func bundledPathsStayInside() {
        let location = BridgeLocation.bundled(contents: contents)
        #expect(location.python.path == "/Applications/Moyo.app/Contents/Resources/python/bin/python3.13")
        #expect(location.script.path == "/Applications/Moyo.app/Contents/Resources/bridge/bridge.py")
    }

    @Test("Le bundle désigne au pont son binaire, ses modèles et sa configuration")
    func bundledCarriesEnginePaths() {
        let environment = BridgeLocation.bundled(contents: contents).environment
        #expect(environment["MOYO_KATAGO"] == "/Applications/Moyo.app/Contents/Helpers/katago")
        #expect(environment["MOYO_MODEL"] == "/Applications/Moyo.app/Contents/Resources/models/play.bin.gz")
        #expect(environment["MOYO_HUMAN_MODEL"] == "/Applications/Moyo.app/Contents/Resources/models/human.bin.gz")
        #expect(environment["MOYO_CONFIG"] == "/Applications/Moyo.app/Contents/Resources/analysis_config.cfg")
    }

    @Test("En développement, le pont tourne depuis le dépôt")
    func developmentUsesTheRepository() {
        let location = BridgeLocation.development(root: projet)
        #expect(location.python.path == "/Users/x/Code/moyo-go/.venv/bin/python")
        #expect(location.script.path == "/Users/x/Code/moyo-go/bridge/bridge.py")
    }

    @Test("En développement, la configuration de KaTrain est laissée intacte")
    func developmentImposesNothing() {
        // Aucune surcharge : le pont lit ~/.katrain comme avant, et une partie
        // jouée depuis le dépôt se comporte exactement comme avec KaTrain.
        #expect(BridgeLocation.development(root: projet).environment.isEmpty)
    }

    @Test("La variable de développement l'emporte sur le bundle")
    func developmentWins() {
        let location = BridgeLocation.resolve(
            environment: ["MOYO_DEV_ROOT": projet.path],
            bundleContents: contents
        )
        #expect(location?.script.path == "/Users/x/Code/moyo-go/bridge/bridge.py")
    }

    @Test("Sans variable, c'est le bundle qui décide")
    func bundleIsTheDefault() {
        let location = BridgeLocation.resolve(environment: [:], bundleContents: contents)
        #expect(location?.script.path == "/Applications/Moyo.app/Contents/Resources/bridge/bridge.py")
    }

    @Test("Une variable vide ne détourne pas vers un dépôt inexistant")
    func emptyVariableIsIgnored() {
        let location = BridgeLocation.resolve(
            environment: ["MOYO_DEV_ROOT": ""],
            bundleContents: contents
        )
        #expect(location?.script.path == "/Applications/Moyo.app/Contents/Resources/bridge/bridge.py")
    }

    @Test("Sans bundle ni variable, il n'y a rien à lancer")
    func nothingResolves() {
        #expect(BridgeLocation.resolve(environment: [:], bundleContents: nil) == nil)
    }
}
