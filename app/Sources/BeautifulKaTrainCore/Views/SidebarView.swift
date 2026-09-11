import SwiftUI

public struct SidebarView: View {
    @Bindable public var session: GameSession

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let state = session.state, let scoring = state.scoring {
                ScoringPanel(detail: scoring) {
                    NotificationCenter.default.post(name: .beautifulKaTrainNewGameRequested, object: nil)
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
            leadFigure
        }
    }

    /// The current lead, always on screen. That the AI is thinking is carried by the
    /// ring around the stone, so the figure never has to give up its place.
    private var leadFigure: some View {
        Group {
            if let lead = session.currentLead {
                Text(ScoreChart.label(for: lead))
                    .font(.system(size: 14))
                    .foregroundStyle(lead >= 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent)
                    .contentTransition(.numericText())
            } else {
                Text("—")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }

    /// The chart carries its own figure now, written at the tip of the last bar, so
    /// there is no separate readout above it.
    private func scoreSection(_ state: GameState) -> some View {
        ScoreChart(scores: session.scoresFromPlayerSide, moveNumber: state.moveNumber)
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

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.settings.opponentName)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
                .lineLimit(1)
            if session.settings.showsRank {
                Text("niveau \(session.settings.humanRankKyu) kyu")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func actions(_ state: GameState) -> some View {
        VStack(spacing: 7) {
            Button {
                session.undo()
            } label: {
                Label("Annuler", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            Button {
                session.passTurn()
            } label: {
                Label("Passer", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .disabled(!session.canAct)
    }
}
