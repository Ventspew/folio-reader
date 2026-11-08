import Foundation

struct LibraryItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var author: String?
    var fileBookmark: Data
    var kind: PublicationFormat
    var pageCount: Int?
    var lastOpened: Date
    var lastPageIndex: Int
    var addedAt: Date
    var coverData: Data?
    var lcpSummary: LCPLicenseInfo?

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        fileBookmark: Data,
        kind: PublicationFormat,
        pageCount: Int? = nil,
        lastOpened: Date = .now,
        lastPageIndex: Int = 0,
        addedAt: Date = .now,
        coverData: Data? = nil,
        lcpSummary: LCPLicenseInfo? = nil
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
        return try URL(
            resolvingBookmarkData: fileBookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
