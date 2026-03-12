import Foundation

struct CodexUsageProvider: UsageProvider {
    let service: ServiceKind = .codex

    func fetchUsage() async throws -> UsageSnapshot {
        let session = try LocalAccountSessionDetector.shared.detectSession(for: service)
        let request = try session.makeRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        let (data, response) = try await URLSession.shared.data(for: request)
        try UsageProviderError.validate(response: response, service: service)

        let payload = try JSONDecoder().decode(CodexUsagePayload.self, from: data)
        let window = payload.rateLimit.primaryWindow ?? payload.rateLimit.secondaryWindow
        let percent = window?.usedPercent ?? 0

        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: Self.details(from: payload)
        )
    }

    private static func details(from payload: CodexUsagePayload) -> String? {
        let pieces = [
            payload.planType?.capitalized,
            payload.email,
            payload.rateLimit.primaryWindow.map {
                "resets in \(UsageSnapshot.resetDescription(after: $0.resetAfterSeconds))"
            }
        ].compactMap { $0 }

        return pieces.isEmpty ? nil : pieces.joined(separator: " • ")
    }
}

enum UsageProviderError: LocalizedError {
    case notImplemented(ServiceKind)
    case missingLocalSession(ServiceKind)
    case invalidResponse(ServiceKind)
    case unauthorized(ServiceKind)
    case challengeRequired(ServiceKind)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let service):
            "\(service.displayName) provider is not implemented yet."
        case .missingLocalSession(let service):
            "\(service.displayName) is not logged in locally."
        case .invalidResponse(let service):
            "Could not read \(service.displayName) usage."
        case .unauthorized(let service):
            "\(service.displayName) local session is expired."
        case .challengeRequired(let service):
            "\(service.displayName) requires reopening the desktop app before usage can be read."
        }
    }

    static func validate(response: URLResponse, service: ServiceKind) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageProviderError.invalidResponse(service)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw UsageProviderError.unauthorized(service)
        default:
            throw UsageProviderError.invalidResponse(service)
        }
    }
}

private struct CodexUsagePayload: Decodable {
    let email: String?
    let planType: String?
    let rateLimit: RateLimit

    enum CodingKeys: String, CodingKey {
        case email
        case rateLimit = "rate_limit"
        case planType = "plan_type"
    }
}

private struct RateLimit: Decodable {
    let primaryWindow: RateLimitWindow?
    let secondaryWindow: RateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Double
    let resetAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
    }
}
