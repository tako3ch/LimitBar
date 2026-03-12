import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let widgetController: WidgetWindowController
    @Published private(set) var menuBarTitle: String

    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.widgetController = WidgetWindowController()
        self.usageStore = UsageStore(
            settings: settings,
            providers: [
                AnyUsageProvider(CodexUsageProvider()),
                AnyUsageProvider(ClaudeCodeUsageProvider())
            ]
        )
        self.menuBarTitle = AppModel.makeMenuBarTitle(
            snapshots: [],
            settings: settings
        )

        Publishers.CombineLatest4(
            usageStore.$snapshots,
            settings.$appLanguage,
            settings.$codexConnected,
            settings.$claudeConnected
        )
        .map { [weak settings] snapshots, _, _, _ in
            guard let settings else { return "" }
            return AppModel.makeMenuBarTitle(snapshots: snapshots, settings: settings)
        }
        .removeDuplicates()
        .sink { [weak self] title in
            self?.menuBarTitle = title
        }
        .store(in: &cancellables)

        usageStore.$snapshots
            .combineLatest(
                settings.$widgetEnabled
                    .combineLatest(settings.$widgetAlwaysOnTop)
                    .combineLatest(settings.$widgetSize)
                    .combineLatest(settings.$widgetPosition)
                    .combineLatest(settings.$displayMode)
            )
            .sink { [weak self] _, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.widgetController.update(using: self.usageStore, settings: self.settings)
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        usageStore.start()
        widgetController.update(using: usageStore, settings: settings)
    }

    private static func makeMenuBarTitle(snapshots: [UsageSnapshot], settings: SettingsStore) -> String {
        let values = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.service, Int($0.clampedPercent)) })
        let labels = settings.connectedServices.compactMap { service -> String? in
            guard let value = values[service] else { return nil }
            return "\(service.shortLabel) \(value)%"
        }
        return labels.isEmpty ? AppStrings(language: settings.appLanguage).setup : labels.joined(separator: " / ")
    }
}
