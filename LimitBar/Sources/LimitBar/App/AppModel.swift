import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let historyStore: UsageHistoryStore
    let widgetController: WidgetWindowController
    @Published private(set) var menuBarTitle: String

    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var reportWindow: NSWindow?

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.historyStore = UsageHistoryStore()
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

        Publishers.CombineLatest3(
            usageStore.$snapshots,
            settings.$codexConnected,
            settings.$claudeConnected
        )
        .map { [weak settings] snapshots, _, _ in
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

        usageStore.$snapshots
            .filter { !$0.isEmpty }
            .sink { [weak self] snapshots in
                self?.historyStore.record(snapshots: snapshots)
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        usageStore.start()
        widgetController.update(using: usageStore, settings: settings)
    }

    func showReportWindow() {
        if let w = reportWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = UsageReportView(historyStore: historyStore, settings: settings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = settings.appLanguage.isJapanese ? "使用量レポート" : "Usage Report"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reportWindow = window
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
