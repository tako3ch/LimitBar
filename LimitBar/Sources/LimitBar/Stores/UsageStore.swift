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

        let results = await withTaskGroup(of: Result<UsageSnapshot, Error>.self) { group in
            for provider in activeProviders {
                group.addTask {
                    do {
                        return .success(try await provider.fetchUsage())
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var snapshots: [UsageSnapshot] = []
            var errors: [String] = []

            for await result in group {
                switch result {
                case .success(let snapshot):
                    snapshots.append(snapshot)
                case .failure(let error):
                    handleConnectionFailure(error)
                    errors.append(error.localizedDescription)
                }
            }

            return (snapshots, errors)
        }

        let orderedSnapshots = results.0.sorted {
            (ServiceKind.allCases.firstIndex(of: $0.service) ?? 0) < (ServiceKind.allCases.firstIndex(of: $1.service) ?? 0)
        }

        snapshots = orderedSnapshots
        handleNotifications(for: orderedSnapshots)
        lastRefreshError = results.1.isEmpty ? nil : results.1.joined(separator: "\n")
    }

    func disconnect(_ service: ServiceKind) {
        snapshots.removeAll { $0.service == service }
        previousPercent[service] = nil
        didNotifyLimit[service] = nil

        if snapshots.isEmpty {
            lastRefreshError = nil
        }
    }

    private func handleConnectionFailure(_ error: Error) {
        guard let providerError = error as? UsageProviderError else { return }

        switch providerError {
        case .missingLocalSession(let service),
             .localClientNotInstalled(let service, _),
             .unauthorized(let service):
            settings.disconnect(service)
            disconnect(service)
        case .notImplemented,
             .browserDataAccessDenied,
             .invalidResponse,
             .challengeRequired:
            break
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer?.tolerance = min(max(settings.refreshInterval * 0.2, 5), 60)
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

    func sendTestNotification() {
        notificationManager.post(
            title: "LimitBar テスト通知",
            body: "通知が正常に届いています。"
        )
    }

    func seedForPreview(_ snapshots: [UsageSnapshot]) {
        self.snapshots = snapshots
    }
}
