import Foundation
import PDFKit

@Observable
@MainActor
final class ReadingSession {
    let itemID: UUID
    let sourceURL: URL
    let securityScoped: Bool
    let document: PDFDocument?
    let lcpInfo: LCPLicenseInfo?
    let temporaryDecryptedURL: URL?
    let clipboard: ClipboardManager

    var currentPageIndex: Int
    var zoomScale: CGFloat = 1.0
    var selectedText: String = ""
    var searchQuery: String = ""
    var searchMatches: [PDFSelection] = []
    var activeSearchIndex: Int = 0
    var awaitingPassphrase: Bool = false
    var lcpBlockedReason: String?

    init(
        itemID: UUID,
        sourceURL: URL,
        securityScoped: Bool,
        document: PDFDocument?,
        lcpInfo: LCPLicenseInfo?,
        temporaryDecryptedURL: URL? = nil,
        initialPage: Int,
        remainingCopy: Int?,
        awaitingPassphrase: Bool = false,
        lcpBlockedReason: String? = nil
    ) {
        self.itemID = itemID
        self.sourceURL = sourceURL
        self.securityScoped = securityScoped
        self.document = document
        self.lcpInfo = lcpInfo
        self.temporaryDecryptedURL = temporaryDecryptedURL
        self.currentPageIndex = max(0, initialPage)
        self.clipboard = ClipboardManager(remainingCharacters: remainingCopy)
        self.awaitingPassphrase = awaitingPassphrase
        self.lcpBlockedReason = lcpBlockedReason
    }

    var isReadable: Bool { document != nil }
    var pageCount: Int { document?.pageCount ?? lcpInfo?.pageCount ?? 0 }

    func tearDown() {
        if securityScoped {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        if let temporaryDecryptedURL {
            try? FileManager.default.removeItem(at: temporaryDecryptedURL)
        }
    }
}
