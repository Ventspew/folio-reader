import SwiftUI

@main
struct FolioApp: App {
    @State private var library = LibraryStore()
    @State private var annotationStore = AnnotationStore()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(annotationStore)
                .preferredColorScheme(colorScheme)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .folioOpenDocument, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Citation") {
                    NotificationCenter.default.post(name: .folioCopyCitation, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                Button("Previous Page") {
                    NotificationCenter.default.post(name: .folioPreviousPage, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Page") {
                    NotificationCenter.default.post(name: .folioNextPage, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Go to Page…") {
                    NotificationCenter.default.post(name: .folioGoToPage, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .folioZoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .folioZoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .folioZoomReset, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Find…") {
                    NotificationCenter.default.post(name: .folioFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(library)
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

extension Notification.Name {
    static let folioOpenDocument = Notification.Name("folio.openDocument")
    static let folioCopyCitation = Notification.Name("folio.copyCitation")
    static let folioPreviousPage = Notification.Name("folio.previousPage")
    static let folioNextPage = Notification.Name("folio.nextPage")
    static let folioGoToPage = Notification.Name("folio.goToPage")
    static let folioZoomIn = Notification.Name("folio.zoomIn")
    static let folioZoomOut = Notification.Name("folio.zoomOut")
    static let folioZoomReset = Notification.Name("folio.zoomReset")
    static let folioFind = Notification.Name("folio.find")
}
