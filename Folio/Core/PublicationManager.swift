import Foundation
import PDFKit

@MainActor
final class PublicationManager {
    private let lcpProvider = LCPDocumentProvider()
    private let licenses = LicenseManager()

    var lcpClientAvailable: Bool { licenses.clientAvailable }
    var lcpClientStatus: String { licenses.clientStatus }

    func detectFormat(for url: URL) -> PublicationFormat {
        switch url.pathExtension.lowercased() {
        case "pdf": .pdf
        case "lcpdf": .lcpdf
        case "lcpl": .lcpl
        default: .unknown
        }
    }

    func metadata(for url: URL) throws -> PublicationMetadata {
        switch detectFormat(for: url) {
        case .pdf:
            let doc = PDFDocument(url: url)
            let attrs = doc?.documentAttributes
            return PublicationMetadata(
                title: (attrs?[PDFDocumentAttribute.titleAttribute] as? String)
                    ?? url.deletingPathExtension().lastPathComponent,
                author: attrs?[PDFDocumentAttribute.authorAttribute] as? String,
                pageCount: doc?.pageCount,
                format: .pdf,
                coverData: nil,
                lcp: nil
            )
        case .lcpdf:
            let info = try lcpProvider.inspect(url: url)
            let cover = try? LCPPackageReader(url: url).coverData()
            return PublicationMetadata(
                title: info.title ?? url.deletingPathExtension().lastPathComponent,
                author: nil,
                pageCount: info.pageCount,
                format: .lcpdf,
                coverData: cover,
                lcp: info
            )
        case .lcpl, .unknown:
            return PublicationMetadata(
                title: url.lastPathComponent,
                author: nil,
                pageCount: nil,
                format: detectFormat(for: url),
                coverData: nil,
                lcp: nil
            )
        }
    }

    func open(url: URL, passphrase: String? = nil) throws -> PublicationOpenResult {
        switch detectFormat(for: url) {
        case .pdf:
            guard let document = PDFDocument(url: url) else {
                return .failed("Unable to open PDF.")
            }
            return .pdf(document, sourceURL: url)
        case .lcpdf:
            return try lcpProvider.open(url: url, passphraseHint: passphrase)
        case .lcpl:
            return .failed("Standalone .lcpl import downloads require a networked LCP service. Open the .lcpdf package instead.")
        case .unknown:
            return .failed("Unsupported file type.")
        }
    }

    func storePassphrase(_ passphrase: String, licenseID: String) throws {
        try licenses.storePassphrase(passphrase, forLicenseID: licenseID)
    }
}
