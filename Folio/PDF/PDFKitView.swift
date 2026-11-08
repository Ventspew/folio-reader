import AppKit
import PDFKit
import SwiftUI

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    @Binding var zoomScale: CGFloat
    @Binding var selectedText: String
    var searchQuery: String
    var goToSearchMatch: PDFSelection?
    var onCopyRequest: ((String) -> Bool)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PDFView {
        let view = FolioPDFView()
        view.autoScales = false
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.windowBackgroundColor
        view.document = document
        view.delegate = context.coordinator
        view.copyHandler = { [weak view] in
            guard let text = view?.currentSelection?.string, !text.isEmpty else { return false }
            return context.coordinator.parent.onCopyRequest?(text) ?? true
        }
        context.coordinator.pdfView = view

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: view
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )

        if let page = document.page(at: currentPageIndex) {
            view.go(to: page)
        }
        view.scaleFactor = zoomScale
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if let folio = view as? FolioPDFView {
            folio.copyHandler = {
                guard let text = folio.currentSelection?.string, !text.isEmpty else { return false }
                return context.coordinator.parent.onCopyRequest?(text) ?? true
            }
        }
        if view.document !== document {
            view.document = document
        }
        if abs(view.scaleFactor - zoomScale) > 0.01 {
            view.scaleFactor = zoomScale
        }
        if let page = view.currentPage,
           let index = document.index(for: page),
           index != currentPageIndex,
           let target = document.page(at: currentPageIndex) {
            view.go(to: target)
        }
        if let match = goToSearchMatch {
            view.setCurrentSelection(match, animate: true)
            view.go(to: match)
        }
        if !searchQuery.isEmpty {
            // Highlighting is handled by selections from the parent search pass.
        }
    }

    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        weak var pdfView: PDFView?

        init(parent: PDFKitView) {
            self.parent = parent
        }

        @objc func selectionChanged(_ notification: Notification) {
            let text = pdfView?.currentSelection?.string ?? ""
            DispatchQueue.main.async {
                self.parent.selectedText = text
            }
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let view = pdfView,
                  let page = view.currentPage,
                  let document = view.document else { return }
            let index = document.index(for: page)
            DispatchQueue.main.async {
                self.parent.currentPageIndex = index
            }
        }
    }
}

/// PDFView subclass that enforces LCP copy allowances before writing to the pasteboard.
final class FolioPDFView: PDFView {
    var copyHandler: (() -> Bool)?

    override func copy(_ sender: Any?) {
        if let copyHandler, !copyHandler() {
            NSSound.beep()
            return
        }
        super.copy(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "c" {
            if let copyHandler, !copyHandler() {
                NSSound.beep()
                return true
            }
        }
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "a" {
            selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
