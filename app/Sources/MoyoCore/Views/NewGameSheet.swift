import SwiftUI

public struct NewGameSheet: View {
    @Bindable public var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GameSession.Settings

    public init(session: GameSession) {
        self.session = session
        _draft = State(initialValue: session.settings)
    }

    private var mode: AIMode { AIMode.mode(for: draft.aiStrategy) }

    private func currentValue(_ setting: AIMode.Setting) -> Double {
        draft.value(for: mode)
            ?? session.settingValue(for: mode)
            ?? (setting.range.lowerBound + setting.range.upperBound) / 2
    }

    private func settingBinding(_ setting: AIMode.Setting) -> Binding<Double> {
        Binding(
            get: { currentValue(setting) },
            set: { draft.setValue($0, for: mode) }
        )
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

                Picker("Adversaire", selection: $draft.aiStrategy) {
                    ForEach(session.modes) { mode in
                        Text(mode.name).tag(mode.id)
                    }
                }
                .onChange(of: draft.aiStrategy) { _, newValue in
                    // Each mode keeps its own setting; on switching, start from what
                    // was last chosen for it, or from what the bridge holds.
                    let switched = AIMode.mode(for: newValue)
                    if draft.value(for: switched) == nil,
                        let value = session.settingValue(for: switched)
                    {
                        draft.setValue(value, for: switched)
                    }
                }

                if !mode.summary.isEmpty {
                    Text(mode.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let setting = mode.setting {
                    LabeledContent(setting.label) {
                        HStack {
                            Slider(value: settingBinding(setting), in: setting.range, step: setting.step)
                            Text(setting.describe(currentValue(setting)))
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .frame(width: 58, alignment: .trailing)
                        }
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
        .frame(width: 400)
    }
}
