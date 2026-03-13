import Foundation
import OSLog
import SQLite3

struct LocalAccountSession {
    let service: ServiceKind
    let label: String
    let bearerToken: String?
    let cookies: [HTTPCookie]
    let organizationID: String?

    func makeRequest(url: URL, userAgent: String? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if !cookies.isEmpty {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }

        if let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        return request
    }
}

struct LocalAccountSessionDetector: Sendable {
    static let shared = LocalAccountSessionDetector()

    private let logger = Logger(subsystem: "LimitBar", category: "LocalAccountSessionDetector")

    func hasSession(for service: ServiceKind) -> Bool {
        (try? detectSession(for: service)) != nil
    }

    func detectSession(for service: ServiceKind) throws -> LocalAccountSession {
        switch service {
        case .codex:
            try detectCodexSession()
        case .claudeCode:
            try detectClaudeSession()
        }
    }

    private func detectCodexSession() throws -> LocalAccountSession {
        do {
            return try CodexDesktopSessionService.shared.detectSession()
        } catch {
            logger.error("Codex desktop session detection failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private func detectClaudeSession() throws -> LocalAccountSession {
        if let storedSession = try? ClaudeWebSessionStore.shared.loadSession()?.localSession {
            return storedSession
        }

        do {
            return try BrowserClaudeSessionDetector.shared.detectSession()
        } catch UsageProviderError.missingLocalSession(.claudeCode) {
            logger.info("Claude browser session was not found")
        } catch UsageProviderError.browserDataAccessDenied(.claudeCode, let browserName) {
            logger.error("Claude browser session detection was denied for \(browserName, privacy: .public)")
            throw UsageProviderError.browserDataAccessDenied(.claudeCode, browserName: browserName)
        } catch {
            logger.error("Claude browser session detection failed: \(String(describing: error), privacy: .public)")
        }

        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Claude")
            .appending(path: "Cookies")

        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw UsageProviderError.missingLocalSession(.claudeCode)
        }

        let cookies = try loadCookies(from: databaseURL, matching: ["%claude.ai%", "%anthropic.com%"])
        guard !cookies.isEmpty else {
            throw UsageProviderError.missingLocalSession(.claudeCode)
        }

        let organizationID = cookies.first { $0.name == "lastActiveOrg" }?.value
        let hasSessionKey = cookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
        guard hasSessionKey else {
            throw UsageProviderError.missingLocalSession(.claudeCode)
        }

        let label: String
        if let organizationID, !organizationID.isEmpty {
            label = "Workspace \(organizationID.prefix(8))"
        } else {
            label = ServiceKind.claudeCode.accountLabel
        }

        return LocalAccountSession(
            service: .claudeCode,
            label: label,
            bearerToken: nil,
            cookies: cookies,
            organizationID: organizationID
        )
    }

    private func loadCookies(from databaseURL: URL, matching patterns: [String]) throws -> [HTTPCookie] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw UsageProviderError.missingLocalSession(.claudeCode)
        }
        defer { sqlite3_close(database) }

        let placeholders = patterns.map { _ in "host_key LIKE ?" }.joined(separator: " OR ")
        let query = """
        SELECT host_key, path, is_secure, expires_utc, name, value
        FROM cookies
        WHERE \(placeholders)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw UsageProviderError.invalidResponse(.claudeCode)
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, pattern) in patterns.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), pattern, -1, transient)
        }

        var results: [HTTPCookie] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let domainCString = sqlite3_column_text(statement, 0),
                let pathCString = sqlite3_column_text(statement, 1),
                let nameCString = sqlite3_column_text(statement, 4),
                let valueCString = sqlite3_column_text(statement, 5)
            else {
                continue
            }

            let domain = String(cString: domainCString)
            let path = String(cString: pathCString)
            let name = String(cString: nameCString)
            let value = String(cString: valueCString)

            guard !value.isEmpty else { continue }

            var properties: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .path: path,
                .name: name,
                .value: value,
                .secure: sqlite3_column_int(statement, 2) != 0 ? "TRUE" : "FALSE"
            ]

            let expires = sqlite3_column_int64(statement, 3)
            if let expirationDate = Self.chromeDate(from: expires) {
                properties[.expires] = expirationDate
            }

            if let cookie = HTTPCookie(properties: properties) {
                results.append(cookie)
            }
        }

        return results
    }

    static func decodeJWTProfile(from token: String?) -> JWTProfile? {
        guard let token else { return nil }
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard
            let data = Data(base64Encoded: payload),
            let profile = try? JSONDecoder().decode(JWTProfile.self, from: data)
        else {
            return nil
        }

        return profile
    }

    static func chromeDate(from rawValue: Int64) -> Date? {
        guard rawValue > 0 else { return nil }
        let seconds = TimeInterval(rawValue) / 1_000_000 - 11_644_473_600
        return Date(timeIntervalSince1970: seconds)
    }
}

struct CodexAuthFile: Decodable {
    let tokens: Tokens

    struct Tokens: Decodable {
        let accessToken: String?
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case idToken = "id_token"
        }
    }
}

struct JWTProfile: Decodable {
    let email: String?
    let auth: JWTAuthPayload?

    enum CodingKeys: String, CodingKey {
        case email
        case auth = "https://api.openai.com/auth"
    }

    var planType: String? {
        auth?.chatgptPlanType
    }
}

struct JWTAuthPayload: Decodable {
    let chatgptPlanType: String?

    enum CodingKeys: String, CodingKey {
        case chatgptPlanType = "chatgpt_plan_type"
    }
}
