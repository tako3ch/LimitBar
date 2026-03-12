import Foundation
import Security

struct StoredClaudeSession: Codable {
    let label: String
    let organizationID: String?
    let cookies: [StoredCookie]

    var localSession: LocalAccountSession? {
        let validCookies = cookies.compactMap(\.httpCookie).filter { !$0.isExpired }
        let hasSessionKey = validCookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
        guard hasSessionKey else { return nil }

        return LocalAccountSession(
            service: .claudeCode,
            label: label,
            bearerToken: nil,
            cookies: validCookies,
            organizationID: organizationID
        )
    }
}

struct StoredCookie: Codable {
    let domain: String
    let path: String
    let name: String
    let value: String
    let isSecure: Bool
    let expiresDate: Date?

    init?(cookie: HTTPCookie) {
        guard !cookie.name.isEmpty, !cookie.value.isEmpty else { return nil }
        domain = cookie.domain
        path = cookie.path
        name = cookie.name
        value = cookie.value
        isSecure = cookie.isSecure
        expiresDate = cookie.expiresDate
    }

    var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: path,
            .name: name,
            .value: value,
            .secure: isSecure ? "TRUE" : "FALSE"
        ]

        if let expiresDate {
            properties[.expires] = expiresDate
        }

        return HTTPCookie(properties: properties)
    }
}

private extension HTTPCookie {
    var isExpired: Bool {
        if let expiresDate {
            return expiresDate <= .now
        }
        return false
    }
}

enum ClaudeWebSessionStoreError: LocalizedError {
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            "Stored Claude session could not be read."
        case .unexpectedStatus(let status):
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error: \(status)"
        }
    }
}

struct ClaudeWebSessionStore {
    static let shared = ClaudeWebSessionStore()

    private let serviceName = "LimitBar.ClaudeWebSession"
    private let accountName = "claudeCode"

    func loadSession() throws -> StoredClaudeSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let session = try? JSONDecoder().decode(StoredClaudeSession.self, from: data)
            else {
                throw ClaudeWebSessionStoreError.invalidData
            }
            return session
        case errSecItemNotFound:
            return nil
        default:
            throw ClaudeWebSessionStoreError.unexpectedStatus(status)
        }
    }

    func saveSession(_ session: StoredClaudeSession) throws {
        let data = try JSONEncoder().encode(session)
        let query = baseQuery
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw ClaudeWebSessionStoreError.unexpectedStatus(updateStatus)
        }

        var item = query
        item[kSecValueData as String] = data

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ClaudeWebSessionStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteSession() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ClaudeWebSessionStoreError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
    }
}
