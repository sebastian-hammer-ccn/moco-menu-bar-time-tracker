import Foundation
import Security

enum KeychainStore {
    private static let service = "com.mocobar.api-key"
    private static let account = "moco"

    static func load() throws -> String? {
        var result: CFTypeRef?
        var loadQuery = query
        loadQuery[kSecReturnData as String] = true
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.operation(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    static func save(_ value: String) throws {
        let attributes = [kSecValueData as String: Data(value.utf8)] as CFDictionary
        let status = SecItemUpdate(query as CFDictionary, attributes)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(value.utf8)
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.operation(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.operation(status)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operation(status)
        }
    }

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private enum KeychainError: LocalizedError {
    case operation(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .operation(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unbekannter Schlüsselbundfehler"
            return "API-Key konnte nicht im Schlüsselbund gespeichert werden: \(message)"
        case .invalidData:
            return "Der gespeicherte API-Key im Schlüsselbund ist ungültig."
        }
    }
}
