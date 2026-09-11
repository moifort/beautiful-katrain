import SwiftUI

public struct GameWindow: View {
    @Bindable public var session: GameSession
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isShowingNewGame = false

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(session: session)
                .navigationSplitViewColumnWidth(206)
        } detail: {
            board
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .toolbar {
            if columnVisibility == .detailOnly {
                ToolbarItem(placement: .primaryAction) { compactStatus }
            }
        }
        .sheet(isPresented: $isShowingNewGame) {
            NewGameSheet(session: session)
        }
        .focusedSceneValue(\.gameSession, session)
        .onReceive(NotificationCenter.default.publisher(for: .beautifulKaTrainNewGameRequested)) { _ in
            isShowingNewGame = true
        }
    }

    private var board: some View {
        ZStack {
            Theme.windowBackground.ignoresSafeArea()
            if let state = session.state {
                BoardView(state: state, isInteractive: isBoardInteractive(state)) { point in
                    if state.status == .scoring {
                        session.toggleDead(row: point.row, col: point.col)
                    } else {
                        session.play(row: point.row, col: point.col)
                    }
                }
                .padding(20)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    /// While counting, clicks mark groups rather than play stones.
    private func isBoardInteractive(_ state: GameState) -> Bool {
        state.status == .scoring ? true : session.canAct
    }

    private var title: String {
        session.state?.status == .finished ? "Partie terminée" : "Partie contre KataGo"
    }

    private var subtitle: String {
        guard let state = session.state else { return "" }
        if state.status == .finished { return state.result ?? "" }
        return "\(state.size)×\(state.size)"
    }

    /// What remains visible once the sidebar is collapsed: the turn, the score, and a
    /// reduced chart. Nothing disappears, it only condenses.
    private var compactStatus: some View {
        HStack(spacing: 8) {
            if let state = session.state {
                TurnIndicator(color: state.toPlay, isThinking: session.thinking.isVisible, diameter: 13)
                if let lead = session.currentLead, abs(lead) >= 0.05 {
                    Image(systemName: lead > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(lead > 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent)
                    Text(String(format: "%.1f", abs(lead)).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 13))
                        .foregroundStyle(lead > 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent)
                        .monospacedDigit()
                }
                ScoreChart(scores: session.scoresFromPlayerSide, moveNumber: state.moveNumber, height: 22)
                    .frame(width: 76)
            }
        }
    }
}
