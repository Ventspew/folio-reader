import AppKit
import SwiftUI

struct LeftSidebar: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AnnotationStore.self) private var annotations
    @Binding var selectedTab: LeftSidebarTab
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sidebar", selection: $selectedTab) {
                ForEach(LeftSidebarTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            switch selectedTab {
            case .library:
                libraryList
            case .contents:
                contentsList
            case .bookmarks:
                bookmarksList
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var libraryList: some View {
        List(selection: Binding(
            get: { library.selectedItemID },
            set: { library.selectedItemID = $0 }
        )) {
            ForEach(library.items) { item in
                Button {
                    do {
                        try library.open(item)
                        selectedTab = .contents
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    HStack(spacing: 10) {
                        cover(for: item)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .lineLimit(2)
                                .font(.body.weight(.medium))
                            HStack(spacing: 6) {
                                Text(item.kind == .lcpdf ? "LCP" : "PDF")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                                if let pages = item.pageCount {
                                    Text("\(pages) pages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .tag(item.id)
                .contextMenu {
                    Button("Remove from Library", role: .destructive) {
                        library.remove(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var contentsList: some View {
        Group {
            if let document = library.readerSession?.document {
                List(0..<document.pageCount, id: \.self) { index in
                    Button {
                        library.readerSession?.currentPageIndex = index
                    } label: {
                        HStack {
                            Text("Page \(index + 1)")
                            Spacer()
                            if library.readerSession?.currentPageIndex == index {
                                Image(systemName: "book.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            } else {
                ContentUnavailableView(
                    "No outline",
                    systemImage: "list.bullet",
                    description: Text("Open a PDF to browse pages.")
                )
            }
        }
    }

    private var bookmarksList: some View {
        Group {
            if let session = library.readerSession {
                let marks = annotations.bookmarks(for: session.itemID)
                if marks.isEmpty {
                    ContentUnavailableView(
                        "No bookmarks",
                        systemImage: "bookmark",
                        description: Text("Add a bookmark from the reader toolbar.")
                    )
                } else {
                    List(marks) { mark in
                        Button {
                            library.readerSession?.currentPageIndex = mark.pageIndex
                        } label: {
                            VStack(alignment: .leading) {
                                Text(mark.label)
                                Text("Page \(mark.pageIndex + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                annotations.removeBookmark(mark.id)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            } else {
                ContentUnavailableView("Open a document", systemImage: "bookmark")
            }
        }
    }

    @ViewBuilder
    private func cover(for item: LibraryItem) -> some View {
        Group {
            if let data = item.coverData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                    Image(systemName: item.kind == .lcpdf ? "lock.doc.fill" : "doc.richtext")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 36, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
