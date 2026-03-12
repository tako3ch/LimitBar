import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [UsageSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshError: String?

    private let settings: SettingsStore
    private let notificationManager: NotificationManager
    private let providers: [AnyUsageProvider]
    private var timer: Timer?
    private var didNotifyLimit: [ServiceKind: Bool] = [:]
    private var previousPercent: [ServiceKind: Double] = [:]

    init(
        settings: SettingsStore,
        providers: [AnyUsageProvider],
        notificationManager: NotificationManager = .shared
    ) {
        self.settings = settings
        self.providers = providers
        self.notificationManager = notificationManager
    }

    func start() {
        scheduleTimer()
        Task {
            await notificationManager.requestAuthorizationIfNeeded()
            await refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func rescheduleTimer() {
        scheduleTimer()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let activeProviders = providers.filter { settings.isConnected($0.service) }
        guard !activeProviders.isEmpty else {
            lastRefreshError = nil
            snapshots = []
            return
        }

        do {
            let results = try await withThrowingTaskGroup(of: UsageSnapshot.self) { group in
                for provider in activeProviders {
                    group.addTask {
                        try await provider.fetchUsage()
                    }
                }

                var snapshots: [UsageSnapshot] = []
                for try await snapshot in group {
                    snapshots.append(snapshot)
                }
                return snapshots.sorted {
                    (ServiceKind.allCases.firstIndex(of: $0.service) ?? 0) < (ServiceKind.allCases.firstIndex(of: $1.service) ?? 0)
                }
            }

            lastRefreshError = nil
            snapshots = results
            handleNotifications(for: results)
        } catch {
            lastRefreshError = error.localizedDescription
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    private func handleNotifications(for snapshots: [UsageSnapshot]) {
        for snapshot in snapshots {
            let threshold = settings.thresholdPercent
            let previous = previousPercent[snapshot.service]
            let crossedThreshold = (previous ?? 0) < threshold && snapshot.clampedPercent >= threshold
            let resetDetected = if let previous {
                snapshot.clampedPercent == 0 || (previous > snapshot.clampedPercent && snapshot.clampedPercent < 10)
            } else {
                false
            }

            if crossedThreshold, settings.notificationsEnabled, didNotifyLimit[snapshot.service] != true {
                notificationManager.post(
                    title: "\(snapshot.service.displayName) almost full",
                    body: "\(Int(snapshot.clampedPercent))% used"
                )
                didNotifyLimit[snapshot.service] = true
            }

            if snapshot.clampedPercent < threshold {
                didNotifyLimit[snapshot.service] = false
            }

            if resetDetected, settings.notificationsEnabled {
                notificationManager.post(
                    title: "\(snapshot.service.displayName) reset",
                    body: "Usage returned to \(Int(snapshot.clampedPercent))%"
                )
                didNotifyLimit[snapshot.service] = false
            }

            previousPercent[snapshot.service] = snapshot.clampedPercent
        }
    }

    func seedForPreview(_ snapshots: [UsageSnapshot]) {
        self.snapshots = snapshots
    }
}
