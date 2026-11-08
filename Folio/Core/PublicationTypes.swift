import Foundation
import PDFKit

enum PublicationFormat: String, Codable, Sendable {
    case pdf
    case lcpdf
    case lcpl
    case unknown
}

enum PublicationOpenResult: Sendable {
    case pdf(PDFDocument, sourceURL: URL)
    /// Decrypted PDF bytes held in a secure temporary file for PDFKit.
    case decryptedPDF(PDFDocument, temporaryFile: URL, license: LCPLicenseInfo, remainingCopy: Int?)
    case lcpRequiresClient(LCPLicenseInfo)
    case lcpRequiresPassphrase(LCPLicenseInfo)
    case failed(String)
}

struct LCPLicenseInfo: Codable, Hashable, Sendable {
    var provider: String?
    var issued: String?
    var profile: String?
    var printAllowance: Int?
    var copyAllowance: Int?
    var start: String?
    var end: String?
    var encrypted: Bool
    var pageCount: Int?
    var title: String?
    var licenseID: String?
    var statusMessage: String
    var isExpired: Bool
    var hasProductionProfile: Bool

    var canCopy: Bool {
        if let copyAllowance { return copyAllowance > 0 }
        return true
    }

    var canPrint: Bool {
        if let printAllowance { return printAllowance > 0 }
        return true
    }
}

struct PublicationMetadata: Sendable {
    var title: String
    var author: String?
    var pageCount: Int?
    var format: PublicationFormat
    var coverData: Data?
    var lcp: LCPLicenseInfo?
}
