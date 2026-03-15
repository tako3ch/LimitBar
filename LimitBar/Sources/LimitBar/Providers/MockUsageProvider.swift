import Foundation

struct MockUsageProvider: UsageProvider {
    let service: ServiceKind
    private let values: [Double]
    private let latency: Duration

    init(service: ServiceKind, values: [Double], latency: Duration = .milliseconds(180)) {
        self.service = service
        self.values = values
        self.latency = latency
    }

    func fetchUsage() async throws -> UsageSnapshot {
        try await Task.sleep(for: latency)
        let calendar = Calendar(identifier: .gregorian)
        let minute = calendar.component(.minute, from: .now)
        let index = minute % max(values.count, 1)
        let percent = values[index]
        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: "Mock sample \(index + 1)",
            weeklyPercent: nil,
            resetAt: Date().addingTimeInterval(3600 * 2),
            weeklyResetAt: nil
        )
    }
}
