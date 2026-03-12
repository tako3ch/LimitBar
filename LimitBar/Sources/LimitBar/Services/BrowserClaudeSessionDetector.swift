import CommonCrypto
import Foundation
import SQLite3
import Security

struct BrowserClaudeSessionDetector: Sendable {
    static let shared = BrowserClaudeSessionDetector()

    func detectSession() throws -> LocalAccountSession {
        for browser in BrowserProfileBrowser.allCases {
            if let session = try detectSession(in: browser) {
                return session
            }
        }

        throw UsageProviderError.missingLocalSession(.claudeCode)
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

                let organizationID = cookies.first { $0.name == "lastActiveOrg" && !$0.value.isEmpty }?.value
                let hasSessionKey = cookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
                guard hasSessionKey else { continue }

                let label = organizationID.map { "Workspace \($0.prefix(8))" } ?? browser.displayName
                return LocalAccountSession(
                    service: .claudeCode,
                    label: label,
                    bearerToken: nil,
                    cookies: cookies,
                    organizationID: organizationID
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
            throw UsageProviderError.invalidResponse(.claudeCode)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT host_key, path, is_secure, expires_utc, name, value, encrypted_value
        FROM cookies
        WHERE host_key LIKE ? OR host_key LIKE ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.claudeCode)
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, "%claude.ai%", -1, transient)
        sqlite3_bind_text(statement, 2, "%anthropic.com%", -1, transient)

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
        if
            let valueCString = sqlite3_column_text(statement, 5)
        {
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
}
