import AppKit
import Foundation

@MainActor
final class ClipboardManager {
    private(set) var remainingCharacters: Int?

    init(remainingCharacters: Int? = nil) {
        self.remainingCharacters = remainingCharacters
    }

    func resetAllowance(_ value: Int?) {
        remainingCharacters = value
    }

    @discardableResult
    func copyPlainText(_ text: String) -> Bool {
        let count = text.count
        if let remaining = remainingCharacters {
            guard count <= remaining else { return false }
            remainingCharacters = remaining - count
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return true
    }

    @discardableResult
    func copyCitation(title: String, author: String?, page: Int, excerpt: String?) -> Bool {
        let body: String
        if let excerpt, !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body = "“\(excerpt)” — \(title)\(author.map { " (\($0))" } ?? ""), p. \(page)."
        } else {
            body = "\(title)\(author.map { " (\($0))" } ?? ""), p. \(page)."
        }
        return copyPlainText(body)
    }
}
