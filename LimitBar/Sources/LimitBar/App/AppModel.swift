import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let widgetController: WidgetWindowController

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.widgetController = WidgetWindowController()
        self.usageStore = UsageStore(
            settings: settings,
            providers: [
                AnyUsageProvider(
                    MockUsageProvider(service: .codex, values: [18, 24, 31, 48, 67, 76, 91, 93, 0, 22, 39, 58])
                ),
                AnyUsageProvider(
                    MockUsageProvider(service: .claudeCode, values: [11, 19, 28, 42, 54, 73, 81, 89, 96, 96, 12, 26])
                )
            ]
        )

        usageStore.$snapshots
            .combineLatest(
                settings.$widgetEnabled,
                settings.$widgetAlwaysOnTop,
                settings.$widgetSize
            )
            .sink { [weak self] _, _, _, _ in
                guard let self else { return }
                self.widgetController.update(using: self.usageStore, settings: self.settings)
            }
            .store(in: &cancellables)
    }

    func start() {
        usageStore.start()
        widgetController.update(using: usageStore, settings: settings)
    }

    var menuBarTitle: String {
        let values = Dictionary(uniqueKeysWithValues: usageStore.snapshots.map { ($0.service, Int($0.clampedPercent)) })
        let codex = values[.codex] ?? 0
        let claude = values[.claudeCode] ?? 0
        return "C \(codex)% / X \(claude)%"
    }
}
