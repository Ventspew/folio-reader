import Foundation

#if FOLIO_LCP_CLIENT
import R2LCPClient

/// Thin adapter around EDRLab’s private R2LCPClient.framework.
/// Enabled only when the framework is linked and FOLIO_LCP_CLIENT is defined.
final class R2LCPClientAdapter: LCPClientProviding, @unchecked Sendable {
    static let shared = R2LCPClientAdapter()

    var isAvailable: Bool { true }

    var statusDescription: String {
        "R2LCPClient linked (authorized EDRLab module)."
    }

    func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> Any {
        try R2LCPClient.createContext(
            jsonLicense: jsonLicense,
            hashedPassphrase: hashedPassphrase,
            pemCrl: pemCrl
        )
    }

    func decrypt(data: Data, using context: Any) -> Data? {
        guard let drm = context as? DRMContext else { return nil }
        return R2LCPClient.decrypt(data: data, using: drm)
    }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
        R2LCPClient.findOneValidPassphrase(
            jsonLicense: jsonLicense,
            hashedPassphrases: hashedPassphrases
        )
    }
}
#endif
