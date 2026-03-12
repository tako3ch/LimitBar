import Foundation

struct ClaudeCodeUsageProvider: UsageProvider {
    let service: ServiceKind = .claudeCode

    func fetchUsage() async throws -> UsageSnapshot {
        throw UsageProviderError.notImplemented(service)
    }
}
