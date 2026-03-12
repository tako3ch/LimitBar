import CommonCrypto
import Foundation
import SQLite3
import Security

struct BrowserCodexSessionDetector: Sendable {
    static let shared = BrowserCodexSessionDetector()

    func detectSession() throws -> LocalAccountSession {
        for browser in BrowserProfileBrowser.allCases {
            if let session = try detectSession(in: browser) {
                return session
            }
        }

        throw UsageProviderError.missingLocalSession(.codex)
    }

    private func detectSession(in browser: BrowserProfileBrowser) throws -> LocalAccountSession? {
        let rootDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: browser.relativeRootPath)

        guard let profileDirectories = try? FileManager.default.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for profileDirectory in profileDirectories where browser.isProfileDirectory(profileDirectory) {
            for cookiesPath in browser.cookieLocations.map({ profileDirectory.appending(path: $0) }) {
                guard FileManager.default.fileExists(atPath: cookiesPath.path) else { continue }

                let cookies = try loadCookies(from: cookiesPath, browser: browser)
                guard !cookies.isEmpty else { continue }

                let hasSession = cookies.contains {
                    ($0.name == "__Secure-next-auth.session-token.0" || $0.name == "__Secure-next-auth.session-token")
                    && !$0.value.isEmpty
                }
                guard hasSession else { continue }

                let label = browserLabel(from: cookies, fallback: browser.displayName)
                return LocalAccountSession(
                    service: .codex,
                    label: label,
                    bearerToken: nil,
                    cookies: cookies,
                    organizationID: nil
                )
            }
        }

        return nil
    }

    private func loadCookies(from databaseURL: URL, browser: BrowserProfileBrowser) throws -> [HTTPCookie] {
        let temporaryDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        try FileManager.default.copyItem(at: databaseURL, to: temporaryDatabaseURL)
        defer { try? FileManager.default.removeItem(at: temporaryDatabaseURL) }

        var database: OpaquePointer?
        guard sqlite3_open_v2(temporaryDatabaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.codex)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT host_key, path, is_secure, expires_utc, name, value, encrypted_value
        FROM cookies
        WHERE host_key LIKE ? OR host_key LIKE ? OR host_key LIKE ? OR host_key LIKE ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.codex)
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, "%chatgpt.com%", -1, transient)
        sqlite3_bind_text(statement, 2, "%openai.com%", -1, transient)
        sqlite3_bind_text(statement, 3, "%auth.openai.com%", -1, transient)
        sqlite3_bind_text(statement, 4, "%sentinel.openai.com%", -1, transient)

        let encryptionKey = try browser.encryptionKey()
        var results: [HTTPCookie] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let domainCString = sqlite3_column_text(statement, 0),
                let pathCString = sqlite3_column_text(statement, 1),
                let nameCString = sqlite3_column_text(statement, 4)
            else {
                continue
            }

            let domain = String(cString: domainCString)
            let path = String(cString: pathCString)
            let name = String(cString: nameCString)
            let value = try cookieValue(from: statement, encryptionKey: encryptionKey)
            guard !value.isEmpty else { continue }

            var properties: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .path: path,
                .name: name,
                .value: value,
                .secure: sqlite3_column_int(statement, 2) != 0 ? "TRUE" : "FALSE"
            ]

            let expires = sqlite3_column_int64(statement, 3)
            if let expirationDate = LocalAccountSessionDetector.chromeDate(from: expires) {
                properties[.expires] = expirationDate
            }

            if let cookie = HTTPCookie(properties: properties) {
                results.append(cookie)
            }
        }

        return results
    }

    private func cookieValue(from statement: OpaquePointer?, encryptionKey: Data) throws -> String {
        if let valueCString = sqlite3_column_text(statement, 5) {
            let plaintext = valueCString.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
            if !plaintext.isEmpty {
                return plaintext
            }
        }

        let encryptedLength = Int(sqlite3_column_bytes(statement, 6))
        guard
            encryptedLength > 0,
            let encryptedPointer = sqlite3_column_blob(statement, 6)
        else {
            return ""
        }

        let encryptedData = Data(bytes: encryptedPointer, count: encryptedLength)
        return try decryptChromiumCookie(encryptedData, encryptionKey: encryptionKey)
    }

    private func decryptChromiumCookie(_ data: Data, encryptionKey: Data) throws -> String {
        guard data.count > 3 else { return "" }

        let payload: Data
        if data.starts(with: Data("v10".utf8)) || data.starts(with: Data("v11".utf8)) {
            payload = data.dropFirst(3)
        } else {
            payload = data
        }

        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var output = Data(count: payload.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputLength: size_t = 0

        let status = output.withUnsafeMutableBytes { outputBytes in
            payload.withUnsafeBytes { payloadBytes in
                encryptionKey.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            encryptionKey.count,
                            ivBytes.baseAddress,
                            payloadBytes.baseAddress,
                            payload.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            return ""
        }

        output.removeSubrange(outputLength..<output.count)
        if let plaintext = String(data: output, encoding: .utf8), !plaintext.isEmpty {
            return plaintext
        }

        if output.count > 32, let plaintext = String(data: output.dropFirst(32), encoding: .utf8), !plaintext.isEmpty {
            return plaintext
        }

        return ""
    }

    private func browserLabel(from cookies: [HTTPCookie], fallback: String) -> String {
        guard
            let cookie = cookies.first(where: { $0.name == "oai-client-auth-info" }),
            let decoded = Optional(cookie.value.removingPercentEncoding ?? cookie.value),
            let data = decoded.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return fallback
        }

        if
            let user = json["user"] as? [String: Any],
            let email = user["email"] as? String,
            !email.isEmpty
        {
            return email
        }

        if
            let identifier = json["last_login_identifier"] as? [String: Any],
            let value = identifier["value"] as? String,
            !value.isEmpty
        {
            return value
        }

        return fallback
    }
}

enum BrowserProfileBrowser: CaseIterable {
    case chrome
    case brave
    case edge
    case arc
    case chromium

    var displayName: String {
        switch self {
        case .chrome:
            "Chrome"
        case .brave:
            "Brave"
        case .edge:
            "Edge"
        case .arc:
            "Arc"
        case .chromium:
            "Chromium"
        }
    }

    var relativeRootPath: String {
        switch self {
        case .chrome:
            "Google/Chrome"
        case .brave:
            "BraveSoftware/Brave-Browser"
        case .edge:
            "Microsoft Edge"
        case .arc:
            "Arc"
        case .chromium:
            "Chromium"
        }
    }

    var cookieLocations: [String] {
        [
            "Cookies",
            "Network/Cookies"
        ]
    }

    func isProfileDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name == "Default" || name.hasPrefix("Profile ")
    }

    func encryptionKey() throws -> Data {
        let password = try keychainPassword()
        let passwordData = Data(password.utf8)
        let saltData = Data("saltysalt".utf8)

        var derivedKey = Data(count: kCCKeySizeAES128)
        let derivedKeyLength = derivedKey.count
        let status = derivedKey.withUnsafeMutableBytes { derivedBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        derivedKeyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw UsageProviderError.invalidResponse(.codex)
        }

        return derivedKey
    }

    private func keychainPassword() throws -> String {
        for (serviceName, accountNames) in keychainEntries {
            for accountName in accountNames {
                if let password = try loadGenericPassword(serviceName: serviceName, accountName: accountName) {
                    return password
                }
            }
        }

        throw UsageProviderError.missingLocalSession(.codex)
    }

    private var keychainEntries: [(String, [String])] {
        switch self {
        case .chrome:
            [("Chrome Safe Storage", ["Chrome", "Chrome Safe Storage"])]
        case .brave:
            [
                ("Brave Safe Storage", ["Brave", "Brave Safe Storage"]),
                ("Brave Browser Safe Storage", ["Brave Browser", "Brave Browser Safe Storage"])
            ]
        case .edge:
            [("Microsoft Edge Safe Storage", ["Microsoft Edge", "Microsoft Edge Safe Storage"])]
        case .arc:
            [("Arc Safe Storage", ["Arc", "Arc Safe Storage"])]
        case .chromium:
            [("Chromium Safe Storage", ["Chromium", "Chromium Safe Storage"])]
        }
    }

    private func loadGenericPassword(serviceName: String, accountName: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
                return nil
            }
            return password
        case errSecItemNotFound:
            return nil
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }
}
