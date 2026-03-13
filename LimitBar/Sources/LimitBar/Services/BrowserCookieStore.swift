import CommonCrypto
import Foundation
import OSLog
import SQLite3
import Security

struct BrowserCookieProfile: Sendable {
    let browserName: String
    let sourceDescription: String
    let cookies: [HTTPCookie]
}

struct BrowserCookieAccessIssue: Sendable {
    let browserName: String
    let error: Error

    var isPermissionDenied: Bool {
        guard let cocoaError = error as? CocoaError else { return false }
        return cocoaError.code == .fileReadNoPermission
    }
}

struct BrowserCookieScanResult: Sendable {
    let profiles: [BrowserCookieProfile]
    let issues: [BrowserCookieAccessIssue]
}

enum SafariCookieAccessState: Sendable {
    case available
    case permissionDenied
    case unavailable
}

struct BrowserCookieStore: Sendable {
    static let shared = BrowserCookieStore()

    private let logger = Logger(subsystem: "LimitBar", category: "BrowserCookieStore")

    func scanProfiles(matching domains: [String]) -> BrowserCookieScanResult {
        let fileManager = FileManager.default
        let normalizedDomains = domains.map { $0.lowercased() }
        var profiles: [BrowserCookieProfile] = []
        var issues: [BrowserCookieAccessIssue] = []

        for browser in ChromiumBrowser.allCases {
            do {
                profiles.append(contentsOf: try loadChromiumProfiles(in: browser, matching: normalizedDomains, fileManager: fileManager))
            } catch {
                issues.append(BrowserCookieAccessIssue(browserName: browser.displayName, error: error))
                logger.error("Failed to inspect \(browser.displayName, privacy: .public) cookies: \(String(describing: error), privacy: .public)")
            }
        }

        do {
            profiles.append(contentsOf: try loadSafariProfiles(matching: normalizedDomains, fileManager: fileManager))
        } catch {
            issues.append(BrowserCookieAccessIssue(browserName: "Safari", error: error))
            if let cocoaError = error as? CocoaError, cocoaError.code == .fileReadNoPermission {
                logger.error("Failed to inspect Safari cookies because the container is not readable. Full Disk Access may be required. Error: \(String(describing: error), privacy: .public)")
            } else {
                logger.error("Failed to inspect Safari cookies: \(String(describing: error), privacy: .public)")
            }
        }

        return BrowserCookieScanResult(profiles: profiles, issues: issues)
    }

    func safariCookieAccessState() -> SafariCookieAccessState {
        let fileManager = FileManager.default

        do {
            for cookieURL in safariCookieLocations(fileManager: fileManager) {
                guard fileManager.fileExists(atPath: cookieURL.path) else { continue }
                _ = try Data(contentsOf: cookieURL, options: .mappedIfSafe)
                return .available
            }
            return .unavailable
        } catch let cocoaError as CocoaError where cocoaError.code == .fileReadNoPermission {
            return .permissionDenied
        } catch {
            logger.error("Failed to inspect Safari cookie access state: \(String(describing: error), privacy: .public)")
            return .unavailable
        }
    }

    private func loadChromiumProfiles(in browser: ChromiumBrowser, matching domains: [String], fileManager: FileManager) throws -> [BrowserCookieProfile] {
        let rootDirectory = fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: browser.relativeRootPath)

        guard let profileDirectories = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.debug("Chromium root not readable for \(browser.displayName, privacy: .public): \(rootDirectory.path(percentEncoded: false), privacy: .public)")
            return []
        }

        return try profileDirectories
            .filter(browser.isProfileDirectory(_:))
            .flatMap { profileDirectory in
                try browser.cookieLocations.compactMap { relativePath in
                    let cookieURL = profileDirectory.appending(path: relativePath)
                    guard fileManager.fileExists(atPath: cookieURL.path) else {
                        return nil
                    }

                    let cookies = try loadChromiumCookies(from: cookieURL, browser: browser, matching: domains)
                    guard !cookies.isEmpty else { return nil }

                    return BrowserCookieProfile(
                        browserName: browser.displayName,
                        sourceDescription: cookieURL.path(percentEncoded: false),
                        cookies: cookies
                    )
                }
            }
    }

    private func loadChromiumCookies(from databaseURL: URL, browser: ChromiumBrowser, matching domains: [String]) throws -> [HTTPCookie] {
        let fileManager = FileManager.default
        let temporaryDatabaseURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        try fileManager.copyItem(at: databaseURL, to: temporaryDatabaseURL)
        defer { try? fileManager.removeItem(at: temporaryDatabaseURL) }

        var database: OpaquePointer?
        guard sqlite3_open_v2(temporaryDatabaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.codex)
        }
        defer { sqlite3_close(database) }

        let placeholders = domains.map { _ in "host_key LIKE ?" }.joined(separator: " OR ")
        let query = """
        SELECT host_key, path, is_secure, expires_utc, name, value, encrypted_value
        FROM cookies
        WHERE \(placeholders)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.codex)
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, domain) in domains.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), "%\(domain)%", -1, transient)
        }

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
            let value = try chromiumCookieValue(from: statement, encryptionKey: encryptionKey)
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

    private func chromiumCookieValue(from statement: OpaquePointer?, encryptionKey: Data) throws -> String {
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

    private func loadSafariProfiles(matching domains: [String], fileManager: FileManager) throws -> [BrowserCookieProfile] {
        return try safariCookieLocations(fileManager: fileManager).compactMap { cookieURL in
            guard fileManager.fileExists(atPath: cookieURL.path) else { return nil }

            let cookies = try loadSafariCookies(from: cookieURL, matching: domains)
            guard !cookies.isEmpty else { return nil }

            return BrowserCookieProfile(
                browserName: "Safari",
                sourceDescription: cookieURL.path(percentEncoded: false),
                cookies: cookies
            )
        }
    }

    private func loadSafariCookies(from cookieURL: URL, matching domains: [String]) throws -> [HTTPCookie] {
        let data = try Data(contentsOf: cookieURL, options: .mappedIfSafe)
        return try SafariBinaryCookieParser().parse(data: data)
            .filter { cookie in
                let domain = cookie.domain.lowercased()
                return domains.contains { domain.contains($0) }
            }
    }

    private func safariCookieLocations(fileManager: FileManager) -> [URL] {
        [
            fileManager.homeDirectoryForCurrentUser
                .appending(path: "Library")
                .appending(path: "Containers")
                .appending(path: "com.apple.Safari")
                .appending(path: "Data")
                .appending(path: "Library")
                .appending(path: "Cookies")
                .appending(path: "Cookies.binarycookies"),
            fileManager.homeDirectoryForCurrentUser
                .appending(path: "Library")
                .appending(path: "Cookies")
                .appending(path: "Cookies.binarycookies")
        ]
    }
}

enum ChromiumBrowser: CaseIterable {
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

private struct SafariBinaryCookieParser {
    func parse(data: Data) throws -> [HTTPCookie] {
        guard data.count >= 8 else { return [] }
        guard String(data: data.prefix(4), encoding: .ascii) == "cook" else { return [] }

        let pageCount = try data.readUInt32BigEndian(at: 4)
        guard pageCount > 0 else { return [] }

        var pageSizes: [Int] = []
        var offset = 8
        for _ in 0..<pageCount {
            let pageSize = try Int(data.readUInt32BigEndian(at: offset))
            pageSizes.append(pageSize)
            offset += 4
        }

        var cookies: [HTTPCookie] = []
        for pageSize in pageSizes {
            guard offset + pageSize <= data.count else { break }
            let pageData = data.subdata(in: offset..<(offset + pageSize))
            cookies.append(contentsOf: parsePage(pageData))
            offset += pageSize
        }

        return cookies
    }

    private func parsePage(_ pageData: Data) -> [HTTPCookie] {
        guard pageData.count >= 8 else { return [] }
        let cookieCount = Int(pageData.readUInt32LittleEndian(at: 4) ?? 0)
        guard cookieCount > 0 else { return [] }

        var cookieOffsets: [Int] = []
        var offset = 8
        for _ in 0..<cookieCount {
            guard let cookieOffset = pageData.readUInt32LittleEndian(at: offset) else { return [] }
            cookieOffsets.append(Int(cookieOffset))
            offset += 4
        }

        return cookieOffsets.compactMap { parseCookie(in: pageData, offset: $0) }
    }

    private func parseCookie(in pageData: Data, offset: Int) -> HTTPCookie? {
        guard
            let size = pageData.readUInt32LittleEndian(at: offset),
            size >= 56,
            offset + Int(size) <= pageData.count
        else {
            return nil
        }

        let cookieData = pageData.subdata(in: offset..<(offset + Int(size)))
        guard
            let flags = cookieData.readUInt32LittleEndian(at: 8),
            let domainOffset = cookieData.readUInt32LittleEndian(at: 16),
            let nameOffset = cookieData.readUInt32LittleEndian(at: 20),
            let pathOffset = cookieData.readUInt32LittleEndian(at: 24),
            let valueOffset = cookieData.readUInt32LittleEndian(at: 28),
            let expiry = cookieData.readDoubleLittleEndian(at: 40)
        else {
            return nil
        }

        guard
            let domain = cookieData.readNullTerminatedString(at: Int(domainOffset)),
            let name = cookieData.readNullTerminatedString(at: Int(nameOffset)),
            let path = cookieData.readNullTerminatedString(at: Int(pathOffset)),
            let value = cookieData.readNullTerminatedString(at: Int(valueOffset)),
            !name.isEmpty,
            !value.isEmpty
        else {
            return nil
        }

        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: path.isEmpty ? "/" : path,
            .name: name,
            .value: value,
            .secure: (flags & 0x1) != 0 ? "TRUE" : "FALSE",
            .expires: Date(timeIntervalSinceReferenceDate: expiry)
        ]

        if (flags & 0x4) != 0 {
            properties[.discard] = "FALSE"
        }

        return HTTPCookie(properties: properties)
    }
}

private extension Data {
    func readUInt32BigEndian(at offset: Int) throws -> UInt32 {
        guard let value = readUInt32LittleEndian(at: offset)?.byteSwapped else {
            throw UsageProviderError.invalidResponse(.codex)
        }
        return value
    }

    func readUInt32LittleEndian(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        var value: UInt32 = 0
        Swift.withUnsafeMutableBytes(of: &value) { destination in
            _ = copyBytes(to: destination, from: offset..<(offset + 4))
        }
        return UInt32(littleEndian: value)
    }

    func readDoubleLittleEndian(at offset: Int) -> Double? {
        guard offset >= 0, offset + 8 <= count else { return nil }
        var value: UInt64 = 0
        Swift.withUnsafeMutableBytes(of: &value) { destination in
            _ = copyBytes(to: destination, from: offset..<(offset + 8))
        }
        return Double(bitPattern: UInt64(littleEndian: value))
    }

    func readNullTerminatedString(at offset: Int) -> String? {
        guard offset >= 0, offset < count else { return nil }
        guard let terminator = self[offset...].firstIndex(of: 0) else { return nil }
        let slice = self[offset..<terminator]
        return String(data: slice, encoding: .utf8)
    }
}
