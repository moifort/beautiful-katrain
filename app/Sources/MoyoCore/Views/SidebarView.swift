import SwiftUI

public struct SidebarView: View {
    @Bindable public var session: GameSession
    @State private var isConfirmingResignation = false

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let state = session.state, let scoring = state.scoring {
                ScoringPanel(detail: scoring) {
                    NotificationCenter.default.post(name: .moyoNewGameRequested, object: nil)
                }
            } else if let state = session.state {
                turnRow(state)
                divider
                scoreSection(state)
                divider
                PlayerTable(rows: playingRows(state))
                divider
                opponentSection
                Spacer(minLength: 0)
                actions(state)
            } else {
                Text("Préparation de la partie…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.sidebarVeil)
        .help(session.engineDescription ?? "")
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 0.5)
    }

    private func turnRow(_ state: GameState) -> some View {
        HStack(spacing: 8) {
            TurnIndicator(color: state.toPlay, isThinking: session.thinking.isVisible)
            Text(Theme.name(state.toPlay))
                .font(.system(size: 14))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 0)
        }
    }

    /// The chart carries its own figure, written small at the tip of the last bar,
    /// so there is no separate readout.
    private func scoreSection(_ state: GameState) -> some View {
        ScoreChart(
            scores: session.scoresFromPlayerSide,
            moveNumber: state.moveNumber,
            annotation: session.currentLead
        )
    }

    /// What is already known per player while the game is on. Territory only exists
    /// once the dead stones are agreed, so it appears at the count, not before.
    private func playingRows(_ state: GameState) -> [PlayerTable.Row] {
        [
            PlayerTable.Row(
                "Captures",
                black: state.captures.byBlack,
                white: state.captures.byWhite
            ),
            PlayerTable.Row("Komi", black: nil, white: session.settings.komi),
        ]
    }

    /// The opponent, and the way to change it: the line that shows the mode is the
    /// line that switches it. Its setting belongs to the new-game sheet, not here —
    /// the sidebar states who you are playing, it is not a control panel.
    private var opponentSection: some View {
        Menu {
            ForEach(session.modes) { mode in
                Button {
                    session.setAI(mode: mode, value: session.settingValue(for: mode))
                } label: {
                    Text(mode.name)
                    if mode.id == session.currentMode.id { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Text(session.currentMode.name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
                .lineLimit(1)
        }
        // The borderless style draws its own indicator; adding one put a second
        // chevron ahead of the label.
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(session.currentMode.summary)
    }

    private func actions(_ state: GameState) -> some View {
        VStack(spacing: 7) {
            Button {
                session.undo()
            } label: {
                Label("Annuler", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!session.canAct)

            Button {
                session.passTurn()
            } label: {
                Label("Passer", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!session.canAct)

            // Available even while the AI is thinking — you give up when you decide
            // to, not when it is your turn. Confirmed because it ends the game.
            Button(role: .destructive) {
                isConfirmingResignation = true
            } label: {
                Label("Abandonner", systemImage: "flag")
                    .frame(maxWidth: .infinity)
            }
            .disabled(state.status != .playing)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .confirmationDialog(
            "Abandonner la partie ?",
            isPresented: $isConfirmingResignation,
            titleVisibility: .visible
        ) {
            Button("Abandonner", role: .destructive) { session.resign() }
            Button("Continuer", role: .cancel) {}
        }
    }
}
