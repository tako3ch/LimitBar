import Foundation
import OSLog

struct BrowserCodexSessionDetector: Sendable {
    static let shared = BrowserCodexSessionDetector()

    private let logger = Logger(subsystem: "LimitBar", category: "BrowserCodexSessionDetector")
    private let domains = ["chatgpt.com", "openai.com", "auth.openai.com", "sentinel.openai.com"]

    func detectSession() throws -> LocalAccountSession {
        let scanResult = BrowserCookieStore.shared.scanProfiles(matching: domains)
        let profiles = scanResult.profiles

        for profile in profiles {
            let cookies = profile.cookies
            let hasSession = cookies.contains {
                ($0.name == "__Secure-next-auth.session-token.0" || $0.name == "__Secure-next-auth.session-token")
                && !$0.value.isEmpty
            }
            guard hasSession else { continue }

            let label = browserLabel(from: cookies, fallback: profile.browserName)
            logger.debug("Resolved Codex browser session from \(profile.sourceDescription, privacy: .public)")

            return LocalAccountSession(
                service: .codex,
                label: label,
                bearerToken: nil,
                cookies: cookies,
                organizationID: nil
            )
        }

        if scanResult.issues.contains(where: { $0.browserName == "Safari" && $0.isPermissionDenied }) {
            throw UsageProviderError.browserDataAccessDenied(.codex, browserName: "Safari")
        }

        logger.info("No browser session found for Codex after inspecting Chromium and Safari cookie stores")
        throw UsageProviderError.missingLocalSession(.codex)
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
