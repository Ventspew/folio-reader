import AppKit
import PDFKit
import SwiftUI

struct ReaderCanvas: View {
    @Environment(LibraryStore.self) private var library
    @Bindable var session: ReaderSession
    let document: PDFDocument

    @State private var activeSearchMatch: PDFSelection?
    @State private var copyBlockedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if !session.searchQuery.isEmpty {
                searchBar
            }

            PDFKitView(
                document: document,
                currentPageIndex: $session.currentPageIndex,
                zoomScale: $session.zoomScale,
                selectedText: $session.selectedText,
                searchQuery: session.searchQuery,
                goToSearchMatch: activeSearchMatch,
                onCopyRequest: { text in
                    let allowed = session.clipboard.copyPlainText(text)
                    if !allowed {
                        copyBlockedMessage = "Copy not allowed: LCP character limit reached."
                    }
                    return allowed
                }
            )
            .background(Color(nsColor: .textBackgroundColor))

            statusBar
        }
        .onChange(of: session.currentPageIndex) { _, newValue in
            library.updateProgress(itemID: session.itemID, pageIndex: newValue)
        }
        .onChange(of: session.searchQuery) { _, query in
            runSearch(query)
        }
        .alert("Copy restricted", isPresented: Binding(
            get: { copyBlockedMessage != nil },
            set: { if !$0 { copyBlockedMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(copyBlockedMessage ?? "")
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Find in document", text: $session.searchQuery)
                .textFieldStyle(.roundedBorder)
            Text(searchStatus)
                .foregroundStyle(.secondary)
                .font(.caption)
            Button("Previous") { stepSearch(-1) }
                .disabled(session.searchMatches.isEmpty)
            Button("Next") { stepSearch(1) }
                .disabled(session.searchMatches.isEmpty)
            Button {
                session.searchQuery = ""
                session.searchMatches = []
                activeSearchMatch = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack {
            Text("Page \(session.currentPageIndex + 1) of \(session.pageCount)")
            Spacer()
            Text("\(Int(session.zoomScale * 100))%")
            if !session.selectedText.isEmpty {
                Text("· \(session.selectedText.count) characters selected")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var searchStatus: String {
        guard !session.searchMatches.isEmpty else {
            return session.searchQuery.isEmpty ? "" : "No matches"
        }
        return "\(session.activeSearchIndex + 1)/\(session.searchMatches.count)"
    }

    private func runSearch(_ query: String) {
        session.searchMatches = []
        session.activeSearchIndex = 0
        activeSearchMatch = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var matches: [PDFSelection] = []
        let found = document.findString(trimmed, withOptions: [.caseInsensitive])
        matches.append(contentsOf: found)
        session.searchMatches = matches
        if let first = matches.first {
            activeSearchMatch = first
            if let page = first.pages.first {
                session.currentPageIndex = document.index(for: page)
            }
        }
    }

    private func stepSearch(_ delta: Int) {
        guard !session.searchMatches.isEmpty else { return }
        let count = session.searchMatches.count
        session.activeSearchIndex = (session.activeSearchIndex + delta + count) % count
        let match = session.searchMatches[session.activeSearchIndex]
        activeSearchMatch = match
        if let page = match.pages.first {
            session.currentPageIndex = document.index(for: page)
        }
    }
}

struct ReaderToolbar: View {
    @Bindable var session: ReaderSession
    @Binding var showFinder: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                session.currentPageIndex = max(0, session.currentPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(session.currentPageIndex <= 0)

            Text("\(session.currentPageIndex + 1) / \(max(session.pageCount, 1))")
                .monospacedDigit()
                .frame(minWidth: 70)

            Button {
                session.currentPageIndex = min(session.pageCount - 1, session.currentPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(session.currentPageIndex >= session.pageCount - 1)

            Divider().frame(height: 16)

            Button {
                session.zoomScale = max(0.4, session.zoomScale - 0.15)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button {
                session.zoomScale = min(4.0, session.zoomScale + 0.15)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }

            Divider().frame(height: 16)

            if showFinder || !session.searchQuery.isEmpty {
                TextField("Find", text: $session.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            } else {
                Button {
                    showFinder = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }
}

struct GoToPageSheet: View {
    @Binding var pageText: String
    let pageCount: Int
    var onGo: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Page")
                .font(.headline)
            TextField("Page number", text: $pageText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Go") {
                    if let page = Int(pageText) {
                        onGo(min(max(page, 1), pageCount))
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}
