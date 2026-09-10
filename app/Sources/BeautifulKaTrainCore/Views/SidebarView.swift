import SwiftUI

public struct SidebarView: View {
    @Bindable public var session: GameSession

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state = session.state {
                turnRow(state)
                divider
                scoreSection(state)
                divider
                capturesRow(state)
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
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.sidebarVeil)
        .help(session.engineDescription ?? "")
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 0.5)
    }

    private func turnRow(_ state: GameState) -> some View {
        HStack(spacing: 6) {
            TurnIndicator(color: state.toPlay, isThinking: session.thinking.isVisible)
            Text(Theme.name(state.toPlay))
                .font(.system(size: 14))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 0)
            Text(trailingLabel(state))
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .contentTransition(.opacity)
        }
    }

    private func trailingLabel(_ state: GameState) -> String {
        if state.status == .finished { return state.result ?? "terminée" }
        return session.thinking.isVisible ? "réfléchit…" : "coup \(state.moveNumber)"
    }

    private func scoreSection(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            leadReadout(state)
            ScoreChart(scores: session.scoresFromPlayerSide, moveNumber: state.moveNumber)
        }
    }

    /// The figure and its arrow, read from the player's side: up and white when they
    /// are ahead, down and red when they are behind.
    private func leadReadout(_ state: GameState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let lead = session.currentLead, abs(lead) >= 0.05 {
                Image(systemName: lead > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(lead > 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent)
                Text(formatted(abs(lead)))
                    .font(.system(size: 21))
                    .foregroundStyle(lead > 0 ? Theme.chartAheadCurrent : Theme.chartBehindCurrent)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            } else if session.currentLead != nil {
                Text("0,0")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.primaryText)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private func capturesRow(_ state: GameState) -> some View {
        HStack {
            Text("Prisonniers")
                .font(.system(size: 13))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
            Spacer(minLength: 0)
            Text("\(state.captures.byBlack) — \(state.captures.byWhite)")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
        }
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
