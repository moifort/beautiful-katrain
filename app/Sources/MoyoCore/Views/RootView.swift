import SwiftUI

public struct RootView: View {
    @State private var session = GameSession()

    public init() {}

    public var body: some View {
        Group {
            switch session.phase {
            case .starting:
                startup
            case .running:
                GameWindow(session: session)
            case .failed(let message):
                failure(message)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            session.start()
            if DemoScript.isRequested() { await DemoScript.run(on: session) }
        }
        .onDisappear { session.stop() }
    }

    private var startup: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Démarrage de KataGo…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundStyle(Theme.secondaryText)
            Text("Le moteur n'a pas démarré")
                .font(.system(size: 16, weight: .medium))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .textSelection(.enabled)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }
}
