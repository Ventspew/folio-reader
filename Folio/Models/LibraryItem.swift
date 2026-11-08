import Foundation

enum PublicationKind: String, Codable, Sendable {
    case pdf
    case lcpdf
    case unknown
}

struct LibraryItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var author: String?
    var fileBookmark: Data
    var kind: PublicationKind
    var pageCount: Int?
    var lastOpened: Date
    var lastPageIndex: Int
    var addedAt: Date
    var coverData: Data?
    var lcpSummary: LCPLicenseSummary?

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        fileBookmark: Data,
        kind: PublicationKind,
        pageCount: Int? = nil,
        lastOpened: Date = .now,
        lastPageIndex: Int = 0,
        addedAt: Date = .now,
        coverData: Data? = nil,
        lcpSummary: LCPLicenseSummary? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileBookmark = fileBookmark
        self.kind = kind
        self.pageCount = pageCount
        self.lastOpened = lastOpened
        self.lastPageIndex = lastPageIndex
        self.addedAt = addedAt
        self.coverData = coverData
        self.lcpSummary = lcpSummary
    }

    func resolvedURL() throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: fileBookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url
    }
}

struct LCPLicenseSummary: Codable, Hashable, Sendable {
    var provider: String?
    var issued: String?
    var profile: String?
    var printAllowance: Int?
    var copyAllowance: Int?
    var start: String?
    var end: String?
    var encrypted: Bool
    var pageCount: Int?
    var title: String?
    var statusMessage: String
}
