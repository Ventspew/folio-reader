import Foundation
import Observation

@Observable
@MainActor
final class AnnotationStore {
    private(set) var highlights: [HighlightRecord] = []
    private(set) var bookmarks: [BookmarkRecord] = []
    private(set) var notes: [NoteRecord] = []

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = support.appendingPathComponent("Folio/annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadAll()
    }

    func highlights(for documentID: UUID) -> [HighlightRecord] {
        highlights.filter { $0.documentID == documentID }.sorted { $0.createdAt > $1.createdAt }
    }

    func bookmarks(for documentID: UUID) -> [BookmarkRecord] {
        bookmarks.filter { $0.documentID == documentID }.sorted { $0.pageIndex < $1.pageIndex }
    }

    func notes(for documentID: UUID) -> [NoteRecord] {
        notes.filter { $0.documentID == documentID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func addHighlight(_ highlight: HighlightRecord) {
        highlights.append(highlight)
        persist()
    }

    func removeHighlight(_ id: UUID) {
        highlights.removeAll { $0.id == id }
        persist()
    }

    func addBookmark(_ bookmark: BookmarkRecord) {
        bookmarks.removeAll { $0.documentID == bookmark.documentID && $0.pageIndex == bookmark.pageIndex }
        bookmarks.append(bookmark)
        persist()
    }

    func removeBookmark(_ id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    func addNote(_ note: NoteRecord) {
        notes.append(note)
        persist()
    }

    func updateNote(_ note: NoteRecord) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[idx] = note
        persist()
    }

    func removeNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    private func loadAll() {
        highlights = load([HighlightRecord].self, from: "highlights.json") ?? []
        bookmarks = load([BookmarkRecord].self, from: "bookmarks.json") ?? []
        notes = load([NoteRecord].self, from: "notes.json") ?? []
    }

    private func persist() {
        save(highlights, to: "highlights.json")
        save(bookmarks, to: "bookmarks.json")
        save(notes, to: "notes.json")
    }

    private func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to name: String) {
        let url = directory.appendingPathComponent(name)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
