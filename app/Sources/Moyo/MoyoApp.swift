import MoyoCore
import SwiftUI

@main
struct MoyoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
            GameCommands()
        }
    }
}
