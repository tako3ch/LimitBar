import AppKit
import Combine
import Foundation
@preconcurrency import Sparkle
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let historyStore: UsageHistoryStore
    let widgetController: WidgetWindowController
    @Published private(set) var menuBarTitle: String
    @Published var menuBarEnabled: Bool

    private let updaterController: SPUStandardUpdaterController?
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var reportWindow: NSWindow?

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.historyStore = UsageHistoryStore()
        self.widgetController = WidgetWindowController()
        self.updaterController = AppEnvironment.supportsUpdates
            ? SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
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
        self.menuBarEnabled = settings.menuBarEnabled

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
        .receive(on: RunLoop.main)
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.widgetController.update(using: self.usageStore, settings: self.settings)
            }
            .store(in: &cancellables)

        usageStore.$snapshots
            .filter { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshots in
                self?.historyStore.record(snapshots: snapshots)
            }
            .store(in: &cancellables)

        // settings → model
        settings.$menuBarEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, self.menuBarEnabled != value else { return }
                self.menuBarEnabled = value
            }
            .store(in: &cancellables)

        // model → settings（逆方向、ループ防止に removeDuplicates）
        $menuBarEnabled
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, self.settings.menuBarEnabled != value else { return }
                self.settings.menuBarEnabled = value
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        if AppEnvironment.isTranslocated {
            showTranslocationAlert()
            return
        }

        usageStore.start()
        widgetController.update(using: usageStore, settings: settings)
        // アプリ起動完了後に Sparkle を開始
        if let updater = updaterController?.updater {
            try? updater.start()
        }
    }

    private func showTranslocationAlert() {
        let alert = NSAlert()
        alert.messageText = "LimitBar を Applications フォルダに移動してください"
        alert.informativeText = """
            DMG から直接起動しているため、macOS のセキュリティ機能により \
            一時フォルダから実行されています。
            このままでは数分後にクラッシュする可能性があります。

            LimitBar.app を /Applications フォルダにコピーしてから再度起動してください。
            """
        alert.addButton(withTitle: "終了")
        alert.alertStyle = .critical
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }

    func checkForUpdates() {
        updaterController?.updater.checkForUpdates()
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
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
