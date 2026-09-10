import SwiftUI

public struct NewGameSheet: View {
    @Bindable public var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GameSession.Settings

    public init(session: GameSession) {
        self.session = session
        _draft = State(initialValue: session.settings)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Nouvelle partie")
                .font(.system(size: 17, weight: .medium))

            Form {
                Picker("Plateau", selection: $draft.size) {
                    Text("9×9").tag(9)
                    Text("13×13").tag(13)
                    Text("19×19").tag(19)
                }
                .pickerStyle(.segmented)

                Picker("Vous jouez", selection: $draft.humanColor) {
                    Text("Noir").tag(PlayerColor.black)
                    Text("Blanc").tag(PlayerColor.white)
                }
                .pickerStyle(.segmented)

                LabeledContent("Niveau de l'IA") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(draft.humanRankKyu) },
                                set: { draft.humanRankKyu = Int($0.rounded()) }
                            ),
                            in: 1...20,
                            step: 1
                        )
                        Text("\(draft.humanRankKyu) kyu")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Commencer") {
                    session.settings = draft
                    session.newGame()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
