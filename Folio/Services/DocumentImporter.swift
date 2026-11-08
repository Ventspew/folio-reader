import Foundation
import UniformTypeIdentifiers

enum DocumentImporter {
    static let allowedContentTypes: [UTType] = [
        .pdf,
        UTType(filenameExtension: "lcpdf") ?? .data,
        UTType(filenameExtension: "lcpl") ?? .json
    ]

    static func kind(for url: URL) -> PublicationKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .pdf
        case "lcpdf":
            return .lcpdf
        default:
            return .unknown
        }
    }
}
