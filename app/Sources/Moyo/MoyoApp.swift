import MoyoCore
import SwiftUI

@main
struct MoyoApp: App {
    @NSApplicationDelegateAdaptor(RecordOpeningDelegate.self) private var delegate

    init() {
        // `Moyo --smoke` vérifie le bundle depuis son propre sandbox, puis sort.
        // C'est le seul point d'où le test est fidèle : les helpers héritent du
        // sandbox de l'application et n'en ont aucun si on les lance à la main.
        if CommandLine.arguments.contains(BundleSelfTest.flag) {
            exit(BundleSelfTest.run())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
            GameCommands()
            ReviewCommands()
        }
    }
}
