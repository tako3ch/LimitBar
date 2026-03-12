import Foundation

struct ClaudeWebLoginService {
    static let shared = ClaudeWebLoginService()

    func persistSession(from cookies: [HTTPCookie]) async throws -> LocalAccountSession {
        let filteredCookies = cookies.filter(Self.isSupportedCookie)
        let hasSessionKey = filteredCookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
        guard hasSessionKey else {
            throw UsageProviderError.missingLocalSession(.claudeCode)
        }

        let organizationID = try await resolveOrganizationID(from: filteredCookies)
        let label = organizationID.map { "Workspace \($0.prefix(8))" } ?? ServiceKind.claudeCode.accountLabel
        let storedCookies = filteredCookies.compactMap(StoredCookie.init(cookie:))

        try ClaudeWebSessionStore.shared.saveSession(
            StoredClaudeSession(
                label: label,
                organizationID: organizationID,
                cookies: storedCookies
            )
        )

        return LocalAccountSession(
            service: .claudeCode,
            label: label,
            bearerToken: nil,
            cookies: filteredCookies,
            organizationID: organizationID
        )
    }

    private func resolveOrganizationID(from cookies: [HTTPCookie]) async throws -> String? {
        if let organizationID = cookies.first(where: { $0.name == "lastActiveOrg" && !$0.value.isEmpty })?.value {
            return organizationID
        }

        let request = try LocalAccountSession(
            service: .claudeCode,
            label: ServiceKind.claudeCode.accountLabel,
            bearerToken: nil,
            cookies: cookies,
            organizationID: nil
        ).makeRequest(
            url: URL(string: "https://claude.ai/api/organizations")!,
            userAgent: Self.userAgent
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try UsageProviderError.validate(response: response, service: .claudeCode)

        let json = try JSONSerialization.jsonObject(with: data)
        if let organizations = Self.extractOrganizations(from: json) {
            return organizations.first
        }

        return nil
    }

    private static func extractOrganizations(from json: Any) -> [String]? {
        if let items = json as? [[String: Any]] {
            let ids = items.compactMap { $0["uuid"] as? String ?? $0["id"] as? String }
            return ids.isEmpty ? nil : ids
        }

        if let dictionary = json as? [String: Any] {
            if let organizations = dictionary["organizations"] {
                return extractOrganizations(from: organizations)
            }

            if let id = dictionary["uuid"] as? String ?? dictionary["id"] as? String {
                return [id]
            }
        }

        return nil
    }

    private static func isSupportedCookie(_ cookie: HTTPCookie) -> Bool {
        guard !cookie.value.isEmpty else { return false }
        return cookie.domain.contains("claude.ai") || cookie.domain.contains("anthropic.com")
    }

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Claude/1.1 Safari/537.36"
}
