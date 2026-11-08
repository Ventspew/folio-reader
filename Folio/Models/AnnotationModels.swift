import Foundation
import SwiftUI

enum HighlightColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellow
    case green
    case blue
    case pink
    case orange

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .yellow: .yellow.opacity(0.45)
        case .green: .green.opacity(0.35)
        case .blue: .cyan.opacity(0.35)
        case .pink: .pink.opacity(0.4)
        case .orange: .orange.opacity(0.4)
        }
    }
}

struct TextAnchor: Codable, Hashable, Sendable {
    var pageIndex: Int
    var selectedText: String
    /// Normalized bounds relative to page (0...1) when available.
    var bounds: CGRectPayload?
}

struct CGRectPayload: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct HighlightRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var documentID: UUID
    var color: HighlightColor
    var anchor: TextAnchor
    var createdAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        documentID: UUID,
        color: HighlightColor,
        anchor: TextAnchor,
        createdAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.color = color
        self.anchor = anchor
        self.createdAt = createdAt
        self.note = note
    }
}

struct BookmarkRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var documentID: UUID
    var pageIndex: Int
    var label: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        documentID: UUID,
        pageIndex: Int,
        label: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.label = label
        self.createdAt = createdAt
    }
}

struct NoteRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var documentID: UUID
    var pageIndex: Int
    var body: String
    var relatedText: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        documentID: UUID,
        pageIndex: Int,
        body: String,
        relatedText: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.body = body
        self.relatedText = relatedText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
