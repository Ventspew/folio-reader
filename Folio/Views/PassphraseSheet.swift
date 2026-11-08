import SwiftUI

struct PassphraseSheet: View {
    let title: String
    var onSubmit: (String) throws -> Void
    @State private var passphrase = ""
    @State private var errorText: String?
    @State private var isSecure = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock LCP publication")
                .font(.headline)
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Group {
                if isSecure {
                    SecureField("Passphrase from your distributor", text: $passphrase)
                } else {
                    TextField("Passphrase from your distributor", text: $passphrase)
                }
            }
            .textFieldStyle(.roundedBorder)

            Toggle("Show passphrase", isOn: $isSecure.mapInvert)
                .toggleStyle(.checkbox)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Text("Passphrases are stored in the macOS Keychain (this device only), never in plaintext project files.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Unlock") {
                    do {
                        try onSubmit(passphrase)
                        dismiss()
                    } catch {
                        errorText = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private extension Binding where Value == Bool {
    var mapInvert: Binding<Bool> {
        Binding(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}
