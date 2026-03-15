import SwiftUI

@MainActor
enum PreviewSupport {
    static let settings: SettingsStore = {
        let defaults = UserDefaults(suiteName: "PreviewDefaults")!
        defaults.removePersistentDomain(forName: "PreviewDefaults")
        return SettingsStore(defaults: defaults)
    }()

    static let usageStore: UsageStore = {
        let store = UsageStore(
            settings: settings,
            providers: [
                AnyUsageProvider(MockUsageProvider(service: .codex, values: [72])),
                AnyUsageProvider(MockUsageProvider(service: .claudeCode, values: [41]))
            ]
        )
        store.seedForPreview([
            UsageSnapshot(service: .codex, usedPercent: 72, status: .warning, lastUpdated: .now, details: "Mock", weeklyPercent: 54, resetAt: Date().addingTimeInterval(3600 * 2 + 1500), weeklyResetAt: Date().addingTimeInterval(86400 * 5)),
            UsageSnapshot(service: .claudeCode, usedPercent: 41, status: .normal, lastUpdated: .now, details: "Mock", weeklyPercent: 63, resetAt: Date().addingTimeInterval(7200), weeklyResetAt: Date().addingTimeInterval(86400 * 3 + 3600 * 14))
        ])
        return store
    }()
}
