import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let widgetController: WidgetWindowController

    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

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

        // objectWillChange の転送は DispatchQueue.main.async で次のランループまで遅延させる。
        // 同期転送すると SwiftUI のビュー更新サイクル中に別の publish が発火し
        // "Publishing changes from within view updates" 警告が出るため。
        // Task { @MainActor } より DispatchQueue.main.async の方が確実に defer される。
        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            }
            .store(in: &cancellables)

        usageStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
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

    var menuBarTitle: String {
        let values = Dictionary(uniqueKeysWithValues: usageStore.snapshots.map { ($0.service, Int($0.clampedPercent)) })
        let labels = settings.connectedServices.compactMap { service -> String? in
            guard let value = values[service] else { return nil }
            return "\(service.shortLabel) \(value)%"
        }
        return labels.isEmpty ? AppStrings(language: settings.appLanguage).setup : labels.joined(separator: " / ")
    }
}
