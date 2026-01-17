import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("laneSpacingFactor") private var laneSpacingFactor: Double = 0.85
    @AppStorage("revengeModeEnabled") private var revengeModeEnabled: Bool = true

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Gameplay")) {
                    Toggle(isOn: $revengeModeEnabled) {
                        Text("Enable Revenge Mode")
                    }
                    .tint(.orange)
                    HStack {
                        Text("Lane Spacing")
                        Spacer()
                        Text(String(format: "%.0f%%", laneSpacingFactor * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $laneSpacingFactor, in: 0.5...1.0, step: 0.01)
                        .accentColor(.blue)
                        .padding(.vertical, 4)
                }
                Section(header: Text("Game Center")) {
                    GameCenterDebugView()
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
