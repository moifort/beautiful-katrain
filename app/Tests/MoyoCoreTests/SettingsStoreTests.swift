import Foundation
import Testing

@testable import MoyoCore

@Suite("Préférences retenues d'un lancement à l'autre")
struct SettingsStoreTests {
    /// An isolated defaults domain, so the suite never touches the real app's.
    private func store(_ name: String = UUID().uuidString) -> (SettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: name)!
        return (SettingsStore(defaults: defaults, key: "test.settings"), defaults)
    }

    @Test("Un premier lancement n'a rien à charger")
    func emptyOnFirstLaunch() {
        let (store, _) = store()
        #expect(store.load() == nil)
    }

    @Test("Le mode choisi survit au redémarrage")
    func modeSurvives() {
        let (store, defaults) = store()
        var settings = GameSession.Settings()
        settings.aiStrategy = "ai:pro"
        store.save(settings)

        let reopened = SettingsStore(defaults: defaults, key: "test.settings")
        #expect(reopened.load()?.aiStrategy == "ai:pro")
    }

    @Test("Chaque mode retrouve son propre réglage")
    func eachModeKeepsItsOwnSetting() {
        let (store, _) = store()
        var settings = GameSession.Settings()
        settings.setValue(3, for: AIMode.mode(for: "ai:human"))
        settings.setValue(1950, for: AIMode.mode(for: "ai:pro"))
        store.save(settings)

        let loaded = store.load()
        #expect(loaded?.value(for: AIMode.mode(for: "ai:human")) == 3)
        #expect(loaded?.value(for: AIMode.mode(for: "ai:pro")) == 1950)
        #expect(loaded?.value(for: AIMode.mode(for: "ai:jigo")) == nil)
    }

    @Test("Le plateau et la couleur sont retenus aussi")
    func boardAndColourSurvive() {
        let (store, _) = store()
        var settings = GameSession.Settings()
        settings.size = 9
        settings.humanColor = .white
        store.save(settings)

        let loaded = store.load()
        #expect(loaded?.size == 9)
        #expect(loaded?.humanColor == .white)
    }

    @Test("Un enregistrement illisible ne bloque pas le démarrage")
    func corruptedDataIsIgnored() {
        let (store, defaults) = store()
        defaults.set(Data("pas du json".utf8), forKey: "test.settings")
        #expect(store.load() == nil)
    }

    @Test("Effacer ramène aux valeurs par défaut")
    func clearing() {
        let (store, _) = store()
        store.save(GameSession.Settings(aiStrategy: "ai:pro"))
        store.clear()
        #expect(store.load() == nil)
    }

    @Test("Le dernier enregistrement gagne")
    func lastWriteWins() {
        let (store, _) = store()
        store.save(GameSession.Settings(aiStrategy: "ai:pro"))
        store.save(GameSession.Settings(aiStrategy: "ai:human"))
        #expect(store.load()?.aiStrategy == "ai:human")
    }
}
