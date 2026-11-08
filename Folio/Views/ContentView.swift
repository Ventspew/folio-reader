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

    var body: some View {
        navigationBody
            .toolbar { toolbarContent }
            .alert("Something went wrong", isPresented: errorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showGoToPage) {
                GoToPageSheet(pageText: $goToPageText, pageCount: library.readerSession?.pageCount ?? 1) { page in
                    library.readerSession?.currentPageIndex = max(
                        0,
                        min(page - 1, (library.readerSession?.pageCount ?? 1) - 1)
                    )
                }
            }
            .sheet(isPresented: passphrasePresented) {
                PassphraseSheet(title: library.passphrasePromptTitle) { phrase in
                    try library.submitPassphrase(phrase)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .folioOpenDocument)) { _ in openDocument() }
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
            .onReceive(NotificationCenter.default.publisher(for: .folioFind)) { _ in showFinder = true }
            .onReceive(NotificationCenter.default.publisher(for: .folioCopyCitation)) { _ in copyCitation() }
    }

    private var navigationBody: some View {
        NavigationSplitView {
            LeftSidebar(selectedTab: $leftTab)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } content: {
            centerColumn
                .navigationSplitViewColumnWidth(min: 500, ideal: 700)
        } detail: {
            RightSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        }
    }

    @ViewBuilder
    private var centerColumn: some View {
        if let session = library.readerSession {
            if session.isReadable, let document = session.document {
                ReaderCanvas(session: session, document: document)
            } else {
                LCPBlockedView(
                    summary: session.lcpInfo,
                    clientStatus: session.lcpBlockedReason ?? library.lcpClientStatus,
                    onEnterPassphrase: {
                        library.pendingPassphraseItemID = session.itemID
                        library.passphrasePromptTitle = session.lcpInfo?.title
                            ?? library.selectedItem?.title
                            ?? "Publication"
                        library.showPassphraseSheet = true
                    }
                )
            }
        } else {
            WelcomeView(onOpen: openDocument)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: openDocument) {
                Label("Open", systemImage: "folder")
            }
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

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var passphrasePresented: Binding<Bool> {
        Binding(
            get: { library.showPassphraseSheet },
            set: { library.showPassphraseSheet = $0 }
        )
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
                leftTab = item.kind == .lcpdf ? .library : .contents
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func copyCitation() {
        guard let session = library.readerSession,
              let item = library.items.first(where: { $0.id == session.itemID }) else { return }
        let ok = session.clipboard.copyCitation(
            title: item.title,
            author: item.author,
            page: session.currentPageIndex + 1,
            excerpt: session.selectedText
        )
        if !ok {
            errorMessage = "Copy limit reached for this LCP license."
        }
    }
}

enum LeftSidebarTab: String, CaseIterable, Identifiable {
    case library, contents, bookmarks
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
