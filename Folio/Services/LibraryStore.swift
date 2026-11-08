import Foundation
import Observation
import PDFKit

@Observable
@MainActor
final class LibraryStore {
    private(set) var items: [LibraryItem] = []
    var selectedItemID: UUID?
    var readerSession: ReaderSession?

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Folio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("library.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    var selectedItem: LibraryItem? {
        items.first { $0.id == selectedItemID }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        items = (try? decoder.decode([LibraryItem].self, from: data)) ?? []
        items.sort { $0.lastOpened > $1.lastOpened }
    }

    func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    @discardableResult
    func importURL(_ url: URL) throws -> LibraryItem {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let kind = DocumentImporter.kind(for: url)
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var title = url.deletingPathExtension().lastPathComponent
        var author: String?
        var pageCount: Int?
        var coverData: Data?
        var lcpSummary: LCPLicenseSummary?

        switch kind {
        case .pdf:
            if let doc = PDFDocument(url: url) {
                pageCount = doc.pageCount
                if let attrs = doc.documentAttributes {
                    if let t = attrs[PDFDocumentAttribute.titleAttribute] as? String, !t.isEmpty {
                        title = t
                    }
                    if let a = attrs[PDFDocumentAttribute.authorAttribute] as? String, !a.isEmpty {
                        author = a
                    }
                }
            }
        case .lcpdf:
            let inspection = try LCPInspector.inspect(url: url)
            lcpSummary = inspection
            title = inspection.title ?? title
            pageCount = inspection.pageCount
            coverData = try? LCPInspector.extractCover(from: url)
        case .unknown:
            break
        }

        if let existing = items.firstIndex(where: {
            (try? $0.resolvedURL().standardizedFileURL) == url.standardizedFileURL
        }) {
            items[existing].title = title
            items[existing].author = author
            items[existing].pageCount = pageCount
            items[existing].kind = kind
            items[existing].lcpSummary = lcpSummary
            items[existing].coverData = coverData ?? items[existing].coverData
            items[existing].fileBookmark = bookmark
            items[existing].lastOpened = .now
            save()
            selectedItemID = items[existing].id
            return items[existing]
        }

        let item = LibraryItem(
            title: title,
            author: author,
            fileBookmark: bookmark,
            kind: kind,
            pageCount: pageCount,
            coverData: coverData,
            lcpSummary: lcpSummary
        )
        items.insert(item, at: 0)
        selectedItemID = item.id
        save()
        return item
    }

    func open(_ item: LibraryItem) throws {
        let url = try item.resolvedURL()
        let accessed = url.startAccessingSecurityScopedResource()

        switch item.kind {
        case .pdf:
            guard let document = PDFDocument(url: url) else {
                if accessed { url.stopAccessingSecurityScopedResource() }
                throw FolioError.unableToOpenPDF
            }
            readerSession = ReaderSession(
                itemID: item.id,
                url: url,
                securityScoped: accessed,
                document: document,
                lcpSummary: nil,
                initialPage: item.lastPageIndex
            )
        case .lcpdf:
            // Authorized Readium LCP decryption is not available on macOS without
            // EDRLab's private R2LCPClient. Present license metadata only.
            let summary = item.lcpSummary ?? (try? LCPInspector.inspect(url: url))
            readerSession = ReaderSession(
                itemID: item.id,
                url: url,
                securityScoped: accessed,
                document: nil,
                lcpSummary: summary,
                initialPage: item.lastPageIndex
            )
        case .unknown:
            if accessed { url.stopAccessingSecurityScopedResource() }
            throw FolioError.unsupportedFormat
        }

        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].lastOpened = .now
            save()
        }
        selectedItemID = item.id
    }

    func updateProgress(itemID: UUID, pageIndex: Int) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].lastPageIndex = pageIndex
        items[idx].lastOpened = .now
        save()
    }

    func remove(_ item: LibraryItem) {
        if readerSession?.itemID == item.id {
            readerSession?.tearDown()
            readerSession = nil
        }
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id { selectedItemID = nil }
        save()
    }

    func closeReader() {
        readerSession?.tearDown()
        readerSession = nil
    }
}

@Observable
@MainActor
final class ReaderSession {
    let itemID: UUID
    let url: URL
    let securityScoped: Bool
    let document: PDFDocument?
    let lcpSummary: LCPLicenseSummary?
    var currentPageIndex: Int
    var zoomScale: CGFloat = 1.0
    var selectedText: String = ""
    var searchQuery: String = ""
    var searchMatches: [PDFSelection] = []
    var activeSearchIndex: Int = 0
    var remainingCopyCharacters: Int?

    init(
        itemID: UUID,
        url: URL,
        securityScoped: Bool,
        document: PDFDocument?,
        lcpSummary: LCPLicenseSummary?,
        initialPage: Int
    ) {
        self.itemID = itemID
        self.url = url
        self.securityScoped = securityScoped
        self.document = document
        self.lcpSummary = lcpSummary
        self.currentPageIndex = max(0, initialPage)
        if let copy = lcpSummary?.copyAllowance {
            remainingCopyCharacters = copy
        }
    }

    var isLCPBlocked: Bool {
        document == nil && lcpSummary != nil
    }

    var pageCount: Int {
        document?.pageCount ?? lcpSummary?.pageCount ?? 0
    }

    func tearDown() {
        if securityScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func consumeCopyAllowance(characterCount: Int) -> Bool {
        guard var remaining = remainingCopyCharacters else { return true }
        guard characterCount <= remaining else { return false }
        remaining -= characterCount
        remainingCopyCharacters = remaining
        return true
    }
}

enum FolioError: LocalizedError {
    case unableToOpenPDF
    case unsupportedFormat
    case lcpNotSupportedOnMac
    case bookmarkFailed

    var errorDescription: String? {
        switch self {
        case .unableToOpenPDF:
            "Unable to open this PDF."
        case .unsupportedFormat:
            "This file format is not supported."
        case .lcpNotSupportedOnMac:
            "Readium LCP decryption requires EDRLab’s private R2LCPClient, which is not available for this macOS build."
        case .bookmarkFailed:
            "Could not create a security-scoped bookmark for this file."
        }
    }
}
