import Foundation

struct ClaudeCodeUsageProvider: UsageProvider {
    let service: ServiceKind = .claudeCode

    func fetchUsage() async throws -> UsageSnapshot {
        let session = try LocalAccountSessionDetector.shared.detectSession(for: service)
        guard let organizationID = session.organizationID else {
            throw UsageProviderError.missingLocalSession(service)
        }

        let request = try session.makeRequest(
            url: URL(string: "https://claude.ai/api/organizations/\(organizationID)/usage")!,
            userAgent: ClaudeWebLoginService.userAgent
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateClaudeResponse(data: data, response: response)

        let payload = try JSONDecoder().decode(ClaudeUsagePayload.self, from: data)
        let percent = payload.primaryWindow?.usedPercent ?? payload.secondaryWindow?.usedPercent ?? 0

        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: Self.details(from: payload)
        )
    }

    private func validateClaudeResponse(data: Data, response: URLResponse) throws {
        try UsageProviderError.validate(response: response, service: service)

        if let text = String(data: data, encoding: .utf8),
           text.localizedCaseInsensitiveContains("Just a moment") {
            throw UsageProviderError.challengeRequired(service)
        }
    }

    private static func details(from payload: ClaudeUsagePayload) -> String? {
        let pieces = [
            payload.primaryWindow.map {
                "resets in \(UsageSnapshot.resetDescription(after: $0.resetAfterSeconds))"
            },
            payload.secondaryWindow.map {
                "weekly \(Int($0.usedPercent))%"
            }
        ].compactMap { $0 }

        return pieces.isEmpty ? nil : pieces.joined(separator: " • ")
    }
}

private struct ClaudeUsagePayload: Decodable {
    let primaryWindow: ClaudeUsageWindow?
    let secondaryWindow: ClaudeUsageWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct ClaudeUsageWindow: Decodable {
    let usedPercent: Double
    let resetAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
    }
}
