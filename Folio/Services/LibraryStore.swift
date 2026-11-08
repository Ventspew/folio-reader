import Foundation
import Observation
import PDFKit

@Observable
@MainActor
final class LibraryStore {
    private(set) var items: [LibraryItem] = []
    var selectedItemID: UUID?
    var readerSession: ReadingSession?
    var pendingPassphraseItemID: UUID?
    var passphrasePromptTitle: String = ""
    var showPassphraseSheet = false

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let publications = PublicationManager()

    var lcpClientAvailable: Bool { publications.lcpClientAvailable }
    var lcpClientStatus: String { publications.lcpClientStatus }

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
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let meta = try publications.metadata(for: url)
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        if let existing = items.firstIndex(where: {
            (try? $0.resolvedURL().standardizedFileURL) == url.standardizedFileURL
        }) {
            items[existing].title = meta.title
            items[existing].author = meta.author
            items[existing].pageCount = meta.pageCount
            items[existing].kind = meta.format
            items[existing].lcpSummary = meta.lcp
            items[existing].coverData = meta.coverData ?? items[existing].coverData
            items[existing].fileBookmark = bookmark
            items[existing].lastOpened = .now
            save()
            selectedItemID = items[existing].id
            return items[existing]
        }

        let item = LibraryItem(
            title: meta.title,
            author: meta.author,
            fileBookmark: bookmark,
            kind: meta.format,
            pageCount: meta.pageCount,
            coverData: meta.coverData,
            lcpSummary: meta.lcp
        )
        items.insert(item, at: 0)
        selectedItemID = item.id
        save()
        return item
    }

    func open(_ item: LibraryItem, passphrase: String? = nil) throws {
        let url = try item.resolvedURL()
        let accessed = url.startAccessingSecurityScopedResource()

        let result = try publications.open(url: url, passphrase: passphrase)
        switch result {
        case .pdf(let document, _):
            readerSession = ReadingSession(
                itemID: item.id,
                sourceURL: url,
                securityScoped: accessed,
                document: document,
                lcpInfo: nil,
                initialPage: item.lastPageIndex,
                remainingCopy: nil
            )
        case .decryptedPDF(let document, let temp, let license, let remaining):
            readerSession = ReadingSession(
                itemID: item.id,
                sourceURL: url,
                securityScoped: accessed,
                document: document,
                lcpInfo: license,
                temporaryDecryptedURL: temp,
                initialPage: item.lastPageIndex,
                remainingCopy: remaining
            )
        case .lcpRequiresPassphrase(let info):
            readerSession = ReadingSession(
                itemID: item.id,
                sourceURL: url,
                securityScoped: accessed,
                document: nil,
                lcpInfo: info,
                initialPage: item.lastPageIndex,
                remainingCopy: info.copyAllowance,
                awaitingPassphrase: true,
                lcpBlockedReason: nil
            )
            pendingPassphraseItemID = item.id
            passphrasePromptTitle = info.title ?? item.title
            showPassphraseSheet = true
        case .lcpRequiresClient(let info):
            readerSession = ReadingSession(
                itemID: item.id,
                sourceURL: url,
                securityScoped: accessed,
                document: nil,
                lcpInfo: info,
                initialPage: item.lastPageIndex,
                remainingCopy: info.copyAllowance,
                awaitingPassphrase: false,
                lcpBlockedReason: publications.lcpClientStatus
            )
        case .failed(let message):
            if accessed { url.stopAccessingSecurityScopedResource() }
            throw FolioError.message(message)
        }

        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].lastOpened = .now
            if let info = readerSession?.lcpInfo {
                items[idx].lcpSummary = info
            }
            save()
        }
        selectedItemID = item.id
    }

    func submitPassphrase(_ passphrase: String) throws {
        guard let id = pendingPassphraseItemID,
              let item = items.first(where: { $0.id == id }) else { return }
        readerSession?.tearDown()
        readerSession = nil
        try open(item, passphrase: passphrase)
        if readerSession?.isReadable == true {
            showPassphraseSheet = false
            pendingPassphraseItemID = nil
        } else if readerSession?.awaitingPassphrase == true {
            throw FolioError.message("Incorrect passphrase for this LCP license.")
        }
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
        showPassphraseSheet = false
        pendingPassphraseItemID = nil
    }
}

enum FolioError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}
