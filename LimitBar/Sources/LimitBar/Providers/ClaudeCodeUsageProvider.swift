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
        let percent = payload.fiveHour?.utilization ?? payload.sevenDay?.utilization ?? 0

        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: Self.details(from: payload),
            weeklyPercent: payload.sevenDay?.utilization
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
            payload.fiveHour.map {
                "resets in \(UsageSnapshot.resetDescription(after: $0.resetAfterSeconds))"
            },
            payload.sevenDay.map {
                "weekly \(Int($0.utilization))%"
            }
        ].compactMap { $0 }

        return pieces.isEmpty ? nil : pieces.joined(separator: " • ")
    }
}

private struct ClaudeUsagePayload: Decodable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct ClaudeUsageWindow: Decodable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetAfterSeconds: Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: resetsAt) else { return 0 }
        return max(0, Int(date.timeIntervalSinceNow))
    }
}
