import Foundation
import UniformTypeIdentifiers

enum DocumentImporter {
    static let allowedContentTypes: [UTType] = [
        .pdf,
        UTType(filenameExtension: "lcpdf") ?? .data,
        UTType(filenameExtension: "lcpl") ?? .json
    ]
}
