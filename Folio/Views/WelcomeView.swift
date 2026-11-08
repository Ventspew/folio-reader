import SwiftUI

struct WelcomeView: View {
    var onOpen: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Folio")
                .font(.largeTitle.weight(.semibold))
            Text("A native macOS reader for academic PDFs.\nSelect text, copy, search, highlight, and annotate.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button(action: onOpen) {
                Label("Open PDF…", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            VStack(alignment: .leading, spacing: 8) {
                Label("PDFKit text selection & ⌘C copy", systemImage: "checkmark.circle")
                Label("Highlights, notes, bookmarks", systemImage: "checkmark.circle")
                Label("LCPDF import + authorized R2LCPClient seam", systemImage: "checkmark.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
