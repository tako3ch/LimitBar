import Foundation
import Security

struct AccountCredential: Equatable {
    let label: String
    let apiKey: String
}

enum CredentialStoreError: LocalizedError {
    case emptyAPIKey
    case unexpectedStatus(OSStatus)
    case invalidCredentialData

    var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            "API key is required."
        case .unexpectedStatus(let status):
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error: \(status)"
        case .invalidCredentialData:
            "Stored credential could not be read."
        }
    }
}

struct CredentialStore {
    static let shared = CredentialStore()

    private let serviceName = "LimitBar.AccountCredentials"

    func loadCredential(for service: ServiceKind) throws -> AccountCredential? {
        var query = baseQuery(for: service)
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let item = result as? [String: Any],
                let data = item[kSecValueData as String] as? Data,
                let apiKey = String(data: data, encoding: .utf8)
            else {
                throw CredentialStoreError.invalidCredentialData
            }

            let label = (item[kSecAttrLabel as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return AccountCredential(label: label?.isEmpty == false ? label! : service.accountLabel, apiKey: apiKey)
        case errSecItemNotFound:
            return nil
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    func saveCredential(_ credential: AccountCredential, for service: ServiceKind) throws {
        let trimmedAPIKey = credential.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw CredentialStoreError.emptyAPIKey
        }

        let trimmedLabel = credential.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = trimmedLabel.isEmpty ? service.accountLabel : trimmedLabel

        let data = Data(trimmedAPIKey.utf8)
        let query = baseQuery(for: service)
        let attributes: [String: Any] = [
            kSecAttrLabel as String: normalizedLabel,
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }

        var item = query
        item.merge(attributes) { _, new in new }

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteCredential(for service: ServiceKind) throws {
        let status = SecItemDelete(baseQuery(for: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    func hasCredential(for service: ServiceKind) -> Bool {
        (try? loadCredential(for: service)) != nil
    }

    private func baseQuery(for service: ServiceKind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: service.rawValue
        ]
    }
}
