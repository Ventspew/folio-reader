import SwiftUI

struct LCPBlockedView: View {
    let summary: LCPLicenseSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Readium LCP publication", systemImage: "lock.rectangle.on.rectangle")
                    .font(.title2.weight(.semibold))

                Text(summary?.statusMessage ?? "This package is protected with Readium LCP.")
                    .foregroundStyle(.secondary)

                GroupBox("License") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        row("Title", summary?.title)
                        row("Provider", summary?.provider)
                        row("Profile", summary?.profile)
                        row("Pages", summary?.pageCount.map(String.init))
                        row("Print allowance", summary?.printAllowance.map(String.init))
                        row("Copy allowance", summary?.copyAllowance.map(String.init))
                        row("Valid from", summary?.start)
                        row("Valid until", summary?.end)
                        row("Encrypted", summary?.encrypted == true ? "Yes" : "No")
                    }
                    .padding(4)
                }

                GroupBox("Why Folio cannot decrypt this file") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Official Readium Swift LCP support requires EDRLab’s private `R2LCPClient` framework and is currently iOS-oriented. The open-source toolkit does not compile for macOS, and Folio does not implement custom DRM circumvention.")
                        Text("Use Thorium Reader (or another certified LCP app) for encrypted reading. Folio fully supports standard PDFs for studying in Preview-like fashion.")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                Link("Readium LCP documentation", destination: URL(string: "https://github.com/readium/swift-toolkit/blob/develop/docs/Guides/Readium%20LCP.md")!)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value?.isEmpty == false ? value! : "—")
                .textSelection(.enabled)
        }
    }
}
