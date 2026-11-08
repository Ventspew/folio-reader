import SwiftUI

struct RightSidebar: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AnnotationStore.self) private var annotations
    @State private var draftNote = ""
    @State private var highlightColor: HighlightColor = .yellow

    var body: some View {
        VStack(spacing: 0) {
            if let session = library.readerSession {
                header(session: session)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        selectionBox(session: session)
                        highlightsSection(session: session)
                        notesSection(session: session)
                    }
                    .padding(12)
                }
            } else {
                ContentUnavailableView(
                    "Notes & highlights",
                    systemImage: "pencil.and.list.clipboard",
                    description: Text("Open a PDF to annotate.")
                )
            }
        }
    }

    private func header(session: ReaderSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Study")
                .font(.headline)
            if let remaining = session.remainingCopyCharacters {
                Text("LCP copy remaining: \(remaining) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Unlimited copy for this PDF")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private func selectionBox(session: ReaderSession) -> some View {
        GroupBox("Selection") {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.selectedText.isEmpty ? "Select text in the reader." : session.selectedText)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Picker("Color", selection: $highlightColor) {
                        ForEach(HighlightColor.allCases) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)

                    Button("Highlight") {
                        guard !session.selectedText.isEmpty else { return }
                        let record = HighlightRecord(
                            documentID: session.itemID,
                            color: highlightColor,
                            anchor: TextAnchor(
                                pageIndex: session.currentPageIndex,
                                selectedText: session.selectedText,
                                bounds: nil
                            )
                        )
                        annotations.addHighlight(record)
                    }
                    .disabled(session.selectedText.isEmpty)

                    Button("Bookmark page") {
                        annotations.addBookmark(
                            BookmarkRecord(
                                documentID: session.itemID,
                                pageIndex: session.currentPageIndex,
                                label: "Page \(session.currentPageIndex + 1)"
                            )
                        )
                    }
                }
            }
        }
    }

    private func highlightsSection(session: ReaderSession) -> some View {
        let items = annotations.highlights(for: session.itemID)
        return GroupBox("Highlights") {
            if items.isEmpty {
                Text("No highlights yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { highlight in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(highlight.anchor.selectedText)
                                .font(.callout)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(highlight.color.color, in: RoundedRectangle(cornerRadius: 6))
                            HStack {
                                Text("p. \(highlight.anchor.pageIndex + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Go") {
                                    library.readerSession?.currentPageIndex = highlight.anchor.pageIndex
                                }
                                .buttonStyle(.borderless)
                                Button("Delete", role: .destructive) {
                                    annotations.removeHighlight(highlight.id)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    private func notesSection(session: ReaderSession) -> some View {
        let items = annotations.notes(for: session.itemID)
        return GroupBox("Notes") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draftNote)
                    .font(.body)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

                Button("Add note on page \(session.currentPageIndex + 1)") {
                    let body = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !body.isEmpty else { return }
                    annotations.addNote(
                        NoteRecord(
                            documentID: session.itemID,
                            pageIndex: session.currentPageIndex,
                            body: body,
                            relatedText: session.selectedText.isEmpty ? nil : session.selectedText
                        )
                    )
                    draftNote = ""
                }
                .disabled(draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(items) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.body)
                            .font(.callout)
                        Text("p. \(note.pageIndex + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    .contextMenu {
                        Button("Go to page") {
                            library.readerSession?.currentPageIndex = note.pageIndex
                        }
                        Button("Delete", role: .destructive) {
                            annotations.removeNote(note.id)
                        }
                    }
                }
            }
        }
    }
}
