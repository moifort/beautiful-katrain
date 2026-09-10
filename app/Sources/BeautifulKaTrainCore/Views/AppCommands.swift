import SwiftUI

extension Notification.Name {
    public static let beautifulKaTrainNewGameRequested = Notification.Name("BeautifulKaTrain.newGameRequested")
}

/// Lets the menu bar reach the session of whichever window has focus.
public struct GameSessionFocusedValueKey: FocusedValueKey {
    public typealias Value = GameSession
}

extension FocusedValues {
    public var gameSession: GameSession? {
        get { self[GameSessionFocusedValueKey.self] }
        set { self[GameSessionFocusedValueKey.self] = newValue }
    }
}

/// Menu items for the game, mirroring the sidebar actions.
///
/// Every action lives here as well as in the sidebar so it keeps a keyboard
/// shortcut when the sidebar is collapsed.
public struct GameCommands: Commands {
    @FocusedValue(\.gameSession) private var session

    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouvelle partie…") {
                NotificationCenter.default.post(name: .beautifulKaTrainNewGameRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Partie") {
            Button("Passer") { session?.passTurn() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(session?.canAct != true)

            Button("Annuler le coup") { session?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(session?.canAct != true)

            Divider()

            Button("Abandonner") { session?.resign() }
                .disabled(session?.state?.status != .playing)
        }
    }
}
