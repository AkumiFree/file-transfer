import Foundation
#if canImport(Security)
import Security
#endif

enum KeychainError: LocalizedError {
#if canImport(Security)
    case unexpectedStatus(OSStatus)
#endif
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
#if canImport(Security)
        case .unexpectedStatus: return String(localized: "keychain_error")
#endif
        case .encodingFailed: return String(localized: "keychain_encoding_failed")
        case .decodingFailed: return String(localized: "keychain_decoding_failed")
        }
    }
}

final class KeychainStore {
    private let service = "FileTransfer.session"
    private let account = "current"
    private let memoryOnly: Bool
    private var memorySession: StoredSession?

    init(memoryOnly: Bool = false) {
        self.memoryOnly = memoryOnly
    }

    func save(_ session: StoredSession) throws {
        if memoryOnly {
            memorySession = session
            return
        }
#if canImport(Security)
        let data = try JSONEncoder().encode(session)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let result = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
            guard result == errSecSuccess else { throw KeychainError.unexpectedStatus(result) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
#else
        memorySession = session
#endif
    }

    func current() throws -> StoredSession? {
        if memoryOnly { return memorySession }
#if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError.unexpectedStatus(status) }
        guard let session = try? JSONDecoder().decode(StoredSession.self, from: data) else { throw KeychainError.decodingFailed }
        return session
#else
        return memorySession
#endif
    }

    func delete() throws {
        if memoryOnly {
            memorySession = nil
            return
        }
#if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
#else
        memorySession = nil
#endif
    }
}
