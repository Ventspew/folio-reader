import Foundation
import PDFKit

/// Loads LCPDF packages, validates license metadata, and decrypts via an authorized client when present.
@MainActor
final class LCPDocumentProvider {
    private let client: LCPClientProviding
    private let licenses: LicenseManager

    init(
        client: LCPClientProviding = LCPClientFactory.make(),
        licenses: LicenseManager? = nil
    ) {
        self.client = client
        self.licenses = licenses ?? LicenseManager(client: client)
    }

    func inspect(url: URL) throws -> LCPLicenseInfo {
        try LCPPackageReader(url: url).licenseInfo()
    }

    func open(
        url: URL,
        passphraseHint: String? = nil
    ) throws -> PublicationOpenResult {
        let package = try LCPPackageReader(url: url)
        let info = try package.licenseInfo()

        if info.isExpired {
            return .failed(LCPClientError.expired.localizedDescription)
        }

        guard client.isAvailable else {
            return .lcpRequiresClient(info)
        }

        let licenseJSON = try package.licenseJSONString()
        let licenseID = info.licenseID ?? url.lastPathComponent

        var hashed = licenses.knownHashedPassphrases(forLicenseID: licenseID)
        if let passphraseHint, !passphraseHint.isEmpty {
            let h = licenses.hashedPassphrase(from: passphraseHint)
            hashed.insert(h, at: 0)
        }

        guard let validHash = client.findOneValidPassphrase(
            jsonLicense: licenseJSON,
            hashedPassphrases: hashed
        ) else {
            return .lcpRequiresPassphrase(info)
        }

        // Persist plaintext passphrase only when freshly entered.
        if let passphraseHint, !passphraseHint.isEmpty,
           licenses.hashedPassphrase(from: passphraseHint) == validHash {
            try? licenses.storePassphrase(passphraseHint, forLicenseID: licenseID)
        }

        let crl = try package.crlPEM()
        let context = try client.createContext(
            jsonLicense: licenseJSON,
            hashedPassphrase: validHash,
            pemCrl: crl
        )

        let encryptedPDF = try package.encryptedPublicationData()
        guard let decrypted = client.decrypt(data: encryptedPDF, using: context) else {
            return .failed(LCPClientError.decryptionFailed.localizedDescription)
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Folio-LCP-\(UUID().uuidString).pdf")
        try decrypted.write(to: temp, options: [.completeFileProtectionUnlessOpen])

        guard let document = PDFDocument(url: temp) else {
            try? FileManager.default.removeItem(at: temp)
            return .failed("Decrypted payload is not a readable PDF.")
        }

        return .decryptedPDF(
            document,
            temporaryFile: temp,
            license: info,
            remainingCopy: info.copyAllowance
        )
    }
}

/// Read-only LCPDF ZIP package reader (no DRM circumvention).
struct LCPPackageReader {
    let url: URL
    private let archive: ZipReader

    init(url: URL) throws {
        self.url = url
        archive = try ZipReader(url: url)
    }

    func licenseJSONString() throws -> String {
        let data = try archive.data(for: "license.lcpl")
        guard let string = String(data: data, encoding: .utf8) else {
            throw LCPClientError.invalidLicense
        }
        return string
    }

    func encryptedPublicationData() throws -> Data {
        // Spec: publication.pdf must not be ZIP-compressed; still tolerate deflate.
        if let data = try? archive.data(for: "publication.pdf") { return data }
        throw ZipError.entryNotFound("publication.pdf")
    }

    func coverData() -> Data? {
        (try? archive.data(for: "cover.jpg"))
            ?? (try? archive.data(for: "cover.jpeg"))
            ?? (try? archive.data(for: "cover.png"))
    }

    /// CRL is typically fetched from the license / LSD network. Placeholder empty PEM
    /// until the authorized client supplies the production CRL pipeline.
    func crlPEM() throws -> String {
        // R2LCPClient expects a PEM CRL string; EDRLab’s module documents the fetch URL.
        // Without the private client we never reach createContext.
        ""
    }

    func licenseInfo() throws -> LCPLicenseInfo {
        let manifestData = try archive.data(for: "manifest.json")
        let licenseData = try archive.data(for: "license.lcpl")
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any] ?? [:]
        let license = try JSONSerialization.jsonObject(with: licenseData) as? [String: Any] ?? [:]

        let metadata = manifest["metadata"] as? [String: Any]
        let title = metadata?["title"] as? String
        let pageCount = metadata?["numberOfPages"] as? Int
        let readingOrder = manifest["readingOrder"] as? [[String: Any]] ?? []
        let encrypted = readingOrder.contains {
            (($0["properties"] as? [String: Any])?["encrypted"] as? [String: Any]) != nil
        }

        let encryption = license["encryption"] as? [String: Any]
        let rights = license["rights"] as? [String: Any]
        let profile = encryption?["profile"] as? String
        let end = rights?["end"] as? String
        let start = rights?["start"] as? String
        let expired = Self.isExpired(end: end)

        var status = encrypted
            ? "Encrypted Readium LCP publication."
            : "LCP package without encrypted reading-order resources."
        if let end { status += " Ends \(end)." }
        if expired { status += " License expired." }

        return LCPLicenseInfo(
            provider: license["provider"] as? String,
            issued: license["issued"] as? String,
            profile: profile,
            printAllowance: rights?["print"] as? Int,
            copyAllowance: rights?["copy"] as? Int,
            start: start,
            end: end,
            encrypted: encrypted,
            pageCount: pageCount,
            title: title,
            licenseID: license["id"] as? String,
            statusMessage: status,
            isExpired: expired,
            hasProductionProfile: profile?.contains("profile-") == true
        )
    }

    private static func isExpired(end: String?) -> Bool {
        guard let end else { return false }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: end) { return date < Date() }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: end) { return date < Date() }
        return false
    }
}
