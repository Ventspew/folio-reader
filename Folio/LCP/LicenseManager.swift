import Foundation
import CryptoKit
import Security

@MainActor
final class LicenseManager {
    private let client: LCPClientProviding
    private let service = "nl.folio.reader.lcp"

    init(client: LCPClientProviding = LCPClientFactory.make()) {
        self.client = client
    }

    var clientAvailable: Bool { client.isAvailable }
    var clientStatus: String { client.statusDescription }

    func hashedPassphrase(from plaintext: String) -> String {
        let digest = SHA256.hash(data: Data(plaintext.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func storePassphrase(_ passphrase: String, forLicenseID id: String) throws {
        let data = Data(passphrase.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id
        ]
        SecItemDelete(query as CFDictionary)
        var values = query
        values[kSecValueData as String] = data
        values[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(values as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    func loadPassphrase(forLicenseID id: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePassphrase(forLicenseID id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id
        ]
        SecItemDelete(query as CFDictionary)
    }

    func knownHashedPassphrases(forLicenseID id: String) -> [String] {
        if let plain = loadPassphrase(forLicenseID: id) {
            return [hashedPassphrase(from: plain)]
        }
        return []
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain error (\(status))."
        }
    }
}
