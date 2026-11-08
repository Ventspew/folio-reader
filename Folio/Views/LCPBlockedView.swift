import AppKit
import SwiftUI

struct LCPBlockedView: View {
    @Environment(LibraryStore.self) private var library
    let summary: LCPLicenseInfo?
    let clientStatus: String
    var onEnterPassphrase: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Readium LCP publication", systemImage: "lock.rectangle.on.rectangle")
                    .font(.title2.weight(.semibold))

                Text(summary?.statusMessage ?? "This package uses Readium LCP.")
                    .foregroundStyle(.secondary)

                GroupBox("Detected license") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        row("Title", summary?.title)
                        row("Provider", summary?.provider)
                        row("Profile", summary?.profile)
                        row("Pages", summary?.pageCount.map(String.init))
                        row("Print allowance", summary?.printAllowance.map(String.init))
                        row("Copy allowance", summary?.copyAllowance.map(String.init))
                        row("Valid from", summary?.start)
                        row("Valid until", summary?.end)
                        row("Expired", summary?.isExpired == true ? "Yes" : "No")
                        row("Encrypted", summary?.encrypted == true ? "Yes" : "No")
                        row("LCP client linked", library.lcpClientAvailable ? "Yes" : "No")
                    }
                    .padding(4)
                }

                if library.lcpClientAvailable {
                    GroupBox("Passphrase") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("An authorized R2LCPClient is linked. Enter the passphrase from your distributor to decrypt.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button("Enter passphrase…") {
                                onEnterPassphrase?()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    GroupBox("Authorized LCP integration required") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(clientStatus)
                                .font(.callout)
                                .textSelection(.enabled)

                            Text("Folio already implements the LCP package/license pipeline and will decrypt through R2LCPClient once EDRLab provides the macOS module.")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Copy EDRLab request email") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(Self.edrlabEmailDraft, forType: .string)
                                }
                                Link("EDRLab LCP provider guide", destination: URL(string: "https://www.edrlab.org/readium-lcp/how-to-lcp-reading-system-provider/")!)
                                Link("Open in Thorium (certified)", destination: URL(string: "https://www.thoriumreader.com")!)
                            }
                        }
                    }
                }

                GroupBox("What works today in Folio") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("LCPDF detection, metadata, cover, rights parsing", systemImage: "checkmark.circle")
                        Label("Passphrase Keychain storage ready", systemImage: "checkmark.circle")
                        Label("R2LCPClient adapter seam (`Vendor/R2LCPClient`)", systemImage: "checkmark.circle")
                        Label("Standard PDF reading, copy, search, annotations", systemImage: "checkmark.circle")
                    }
                    .font(.callout)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value?.isEmpty == false ? value! : "—").textSelection(.enabled)
        }
    }

    static let edrlabEmailDraft = """
    To: contact@edrlab.org
    Subject: Request for macOS R2LCPClient (test grade) — Folio reader

    Hello EDRLab,

    I am developing Folio, a native macOS academic PDF/LCP reader (SwiftUI + PDFKit).
    Use case: personal and institutional ebook reading of Readium LCP publications (library loans / purchased LCP PDFs).
    Platform: macOS 14+ (Apple silicon).
    We are not building a license server—only a certified reading application.

    Please provide a test-grade macOS R2LCPClient module and integration instructions.
    Project repository: https://github.com/Ventspew/folio-reader

    Thank you.
    """
}
