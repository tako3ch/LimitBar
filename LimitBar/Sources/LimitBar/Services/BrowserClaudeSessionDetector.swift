import Foundation
import OSLog

struct BrowserClaudeSessionDetector: Sendable {
    static let shared = BrowserClaudeSessionDetector()

    private let logger = Logger(subsystem: "LimitBar", category: "BrowserClaudeSessionDetector")
    private let domains = ["claude.ai", "anthropic.com"]

    func detectSession() throws -> LocalAccountSession {
        let scanResult = BrowserCookieStore.shared.scanProfiles(matching: domains)
        let profiles = scanResult.profiles

        for profile in profiles {
            let cookies = profile.cookies
            let organizationID = cookies.first { $0.name == "lastActiveOrg" && !$0.value.isEmpty }?.value
            let hasSessionKey = cookies.contains { $0.name == "sessionKey" && !$0.value.isEmpty }
            guard hasSessionKey else { continue }

            let label = organizationID.map { "Workspace \($0.prefix(8))" } ?? profile.browserName
            logger.debug("Resolved Claude browser session from \(profile.sourceDescription, privacy: .public)")

            return LocalAccountSession(
                service: .claudeCode,
                label: label,
                bearerToken: nil,
                cookies: cookies,
                organizationID: organizationID
            )
        }

        if scanResult.issues.contains(where: { $0.browserName == "Safari" && $0.isPermissionDenied }) {
            throw UsageProviderError.browserDataAccessDenied(.claudeCode, browserName: "Safari")
        }

        logger.info("No browser session found for Claude after inspecting Chromium and Safari cookie stores")
        throw UsageProviderError.missingLocalSession(.claudeCode)
    }
}
