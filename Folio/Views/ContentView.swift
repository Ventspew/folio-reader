import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AnnotationStore.self) private var annotations
    @State private var leftTab: LeftSidebarTab = .library
    @State private var errorMessage: String?
    @State private var showGoToPage = false
    @State private var goToPageText = ""
    @State private var showFinder = false
    @State private var findFocused = false

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            LeftSidebar(selectedTab: $leftTab)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } content: {
            Group {
                if let session = library.readerSession {
                    if session.isLCPBlocked {
                        LCPBlockedView(summary: session.lcpSummary)
                    } else if let document = session.document {
                        ReaderCanvas(session: session, document: document)
                    } else {
                        ContentUnavailableView("Unable to open document", systemImage: "exclamationmark.triangle")
                    }
                } else {
                    WelcomeView(onOpen: openDocument)
                }
            }
            .navigationSplitViewColumnWidth(min: 500, ideal: 700)
        } detail: {
            RightSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    openDocument()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .help("Open PDF or LCPDF")

                if library.readerSession != nil {
                    Button {
                        library.closeReader()
                    } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                }
            }

            ToolbarItemGroup(placement: .principal) {
                if let session = library.readerSession, session.document != nil {
                    ReaderToolbar(session: session, showFinder: $showFinder)
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showGoToPage) {
            GoToPageSheet(pageText: $goToPageText, pageCount: library.readerSession?.pageCount ?? 1) { page in
                library.readerSession?.currentPageIndex = max(0, min(page - 1, (library.readerSession?.pageCount ?? 1) - 1))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioOpenDocument)) { _ in
            openDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioPreviousPage)) { _ in
            guard let session = library.readerSession else { return }
            session.currentPageIndex = max(0, session.currentPageIndex - 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioNextPage)) { _ in
            guard let session = library.readerSession else { return }
            session.currentPageIndex = min(session.pageCount - 1, session.currentPageIndex + 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioGoToPage)) { _ in
            goToPageText = String((library.readerSession?.currentPageIndex ?? 0) + 1)
            showGoToPage = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioZoomIn)) { _ in
            library.readerSession?.zoomScale = min(4.0, (library.readerSession?.zoomScale ?? 1) + 0.15)
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioZoomOut)) { _ in
            library.readerSession?.zoomScale = max(0.4, (library.readerSession?.zoomScale ?? 1) - 0.15)
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioZoomReset)) { _ in
            library.readerSession?.zoomScale = 1.0
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioFind)) { _ in
            showFinder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .folioCopyCitation)) { _ in
            copyCitation()
        }
        .onAppear {
            maybeImportDefaultTestFiles()
        }
    }

    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a PDF or Readium LCPDF package"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let item = try library.importURL(url)
                try library.open(item)
                leftTab = .contents
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func copyCitation() {
        guard let session = library.readerSession,
              let item = library.items.first(where: { $0.id == session.itemID }) else { return }
        let page = session.currentPageIndex + 1
        let selected = session.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let citation: String
        if selected.isEmpty {
            citation = "\(item.title)\(item.author.map { " (\($0))" } ?? ""), p. \(page)."
        } else {
            citation = "“\(selected)” — \(item.title)\(item.author.map { " (\($0))" } ?? ""), p. \(page)."
        }
        if session.consumeCopyAllowance(characterCount: citation.count) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(citation, forType: .string)
        } else {
            errorMessage = "Copy limit reached for this LCP license."
        }
    }

    /// Soft convenience: if the user already has common test PDFs, offer nothing automatic that mutates Downloads.
    private func maybeImportDefaultTestFiles() {
        // Intentionally empty — users open files explicitly.
    }
}

enum LeftSidebarTab: String, CaseIterable, Identifiable {
    case library
    case contents
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "Library"
        case .contents: "Contents"
        case .bookmarks: "Bookmarks"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .contents: "list.bullet"
        case .bookmarks: "bookmark"
        }
    }
}
