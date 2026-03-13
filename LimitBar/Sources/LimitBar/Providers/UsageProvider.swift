import Foundation

extension URLSession {
    /// プロバイダー共通のタイムアウト設定（15秒）
    static let limitBar: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()
}

protocol UsageProvider: Sendable {
    var service: ServiceKind { get }
    func fetchUsage() async throws -> UsageSnapshot
}

struct AnyUsageProvider: UsageProvider {
    let service: ServiceKind
    private let fetcher: @Sendable () async throws -> UsageSnapshot

    init<P: UsageProvider>(_ provider: P) {
        service = provider.service
        fetcher = provider.fetchUsage
    }

    func fetchUsage() async throws -> UsageSnapshot {
        try await fetcher()
    }
}
