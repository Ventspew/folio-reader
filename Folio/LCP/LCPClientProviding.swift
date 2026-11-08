import Foundation

/// Abstraction matching the authorized R2LCPClient surface used by Readium.
/// Folio never embeds DRM secrets; production decryption requires EDRLab’s private module.
protocol LCPClientProviding: AnyObject, Sendable {
    var isAvailable: Bool { get }
    var statusDescription: String { get }

    /// Creates a decryption context from license JSON + hashed passphrase + CRL PEM.
    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> Any

    /// Decrypts one encrypted resource payload.
    func decrypt(data: Data, using context: Any) -> Data?

    /// Finds a valid passphrase hash among known hashes for this license.
    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String?
}

/// Default provider used until `Vendor/R2LCPClient` is supplied by EDRLab.
final class UnavailableLCPClient: LCPClientProviding, @unchecked Sendable {
    static let shared = UnavailableLCPClient()

    var isAvailable: Bool { false }

    var statusDescription: String {
        """
        Authorized LCP decryption is not linked in this Folio build.

        To enable genuine Readium LCP on macOS:
        1. Email contact@edrlab.org requesting a macOS R2LCPClient (test grade).
        2. Provide project name (Folio), use case (personal/academic LCP reading), and roadmap.
        3. Place the framework under Vendor/R2LCPClient and set FOLIO_LCP_CLIENT=1.
        4. Complete EDRLab certification before any production distribution.

        The open-source Readium Swift toolkit currently does not compile for macOS;
        Thorium Desktop uses a certified native LCP module provided by EDRLab.
        """
    }

    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> Any {
        throw LCPClientError.frameworkMissing
    }

    func decrypt(data: Data, using context: Any) -> Data? { nil }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? { nil }
}

enum LCPClientError: LocalizedError {
    case frameworkMissing
    case invalidLicense
    case invalidPassphrase
    case decryptionFailed
    case expired
    case unsupportedProfile(String)

    var errorDescription: String? {
        switch self {
        case .frameworkMissing:
            "R2LCPClient is not installed. Request it from EDRLab (contact@edrlab.org)."
        case .invalidLicense:
            "The LCP license document is invalid."
        case .invalidPassphrase:
            "The passphrase does not unlock this license."
        case .decryptionFailed:
            "LCP decryption failed."
        case .expired:
            "This LCP license has expired."
        case .unsupportedProfile(let profile):
            "Unsupported LCP profile: \(profile)"
        }
    }
}

enum LCPClientFactory {
    /// Returns a live client when compiled with FOLIO_LCP_CLIENT and the vendor module is present.
    static func make() -> LCPClientProviding {
        #if FOLIO_LCP_CLIENT
        return R2LCPClientAdapter.shared
        #else
        return UnavailableLCPClient.shared
        #endif
    }
}
