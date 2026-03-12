import Foundation

struct CodexUsageProvider: UsageProvider {
    let service: ServiceKind = .codex

    func fetchUsage() async throws -> UsageSnapshot {
        throw UsageProviderError.notImplemented(service)
    }
}

enum UsageProviderError: LocalizedError {
    case notImplemented(ServiceKind)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let service):
            "\(service.displayName) provider is not implemented yet."
        }
    }
}
