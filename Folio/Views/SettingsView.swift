import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.inline)

            Section("About") {
                Text("Folio is a native macOS academic PDF reader.")
                Text("Readium LCP decryption requires EDRLab certification and is not bundled.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
        .padding()
    }
}
