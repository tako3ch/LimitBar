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
    private var hasShownSafariAccessPrompt = false
    private var reportWindow: NSWindow?

    private struct WidgetUpdateState: Equatable {
        let isEnabled: Bool
        let alwaysOnTop: Bool
        let widgetSize: WidgetSize
        let widgetPosition: WidgetPosition
        let displayMode: DisplayMode
        let showClaudeWeeklyLimit: Bool
        let showCodexWeeklyLimit: Bool
        let rowCount: Int
    }

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
        bindMenuBarTitle()
        bindWidgetUpdates()
        bindHistoryRecording()
        bindMenuBarEnabled()
    }

    private func bindMenuBarTitle() {
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
            Task { @MainActor [weak self] in
                self?.menuBarTitle = title
            }
        }
        .store(in: &cancellables)
    }

    private func bindWidgetUpdates() {
        let widgetSettings = Publishers.CombineLatest4(
            settings.$widgetEnabled,
            settings.$widgetAlwaysOnTop,
            settings.$widgetSize,
            settings.$widgetPosition
        )
        .combineLatest(
            Publishers.CombineLatest3(
                settings.$displayMode,
                settings.$showClaudeWeeklyLimitInWidget,
                settings.$showCodexWeeklyLimitInWidget
            )
        )

        let widgetStatePublisher = Publishers.CombineLatest(
            usageStore.$snapshots,
            widgetSettings
        )
            .map { [weak settings] combined -> WidgetUpdateState in
                let (snapshots, widgetSettings) = combined
                let ((isEnabled, alwaysOnTop, widgetSize, widgetPosition), (displayMode, showClaudeWeeklyLimit, showCodexWeeklyLimit)) = widgetSettings
                let rowCount = snapshots.reduce(0) { count, snapshot in
                    guard let settings else { return count + 1 }
                    let showsWeekly = settings.showsWeeklyLimitInWidget(for: snapshot.service) && snapshot.clampedWeeklyPercent != nil
                    return count + 1 + (showsWeekly ? 1 : 0)
                }

                return WidgetUpdateState(
                    isEnabled: isEnabled,
                    alwaysOnTop: alwaysOnTop,
                    widgetSize: widgetSize,
                    widgetPosition: widgetPosition,
                    displayMode: displayMode,
                    showClaudeWeeklyLimit: showClaudeWeeklyLimit,
                    showCodexWeeklyLimit: showCodexWeeklyLimit,
                    rowCount: rowCount
                )
            }
            .removeDuplicates()

        widgetStatePublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] (_: WidgetUpdateState) in
                guard let self else { return }
                // Task でラップして現在の SwiftUI 更新サイクル完了後に実行し
                // "Publishing changes from within view updates" 警告を回避する
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.widgetController.update(using: self.usageStore, settings: self.settings)
                }
            })
            .store(in: &cancellables)
    }

    private func bindHistoryRecording() {
        usageStore.$snapshots
            .filter { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshots in
                self?.historyStore.record(snapshots: snapshots)
            }
            .store(in: &cancellables)
    }

    private func bindMenuBarEnabled() {
        settings.$menuBarEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, self.menuBarEnabled != value else { return }
                self.menuBarEnabled = value
            }
            .store(in: &cancellables)

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

        promptForSafariFullDiskAccessIfNeeded()
        usageStore.start()
        widgetController.update(using: usageStore, settings: settings)
        // アプリ起動完了後に Sparkle を開始
        if let updater = updaterController?.updater {
            try? updater.start()
        }
    }

    func setMenuBarEnabledFromUI(_ value: Bool) {
        guard menuBarEnabled != value else { return }
        menuBarEnabled = value
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

    private func promptForSafariFullDiskAccessIfNeeded() {
        guard !hasShownSafariAccessPrompt else { return }

        let defaultBrowser = BrowserLaunchService.shared.defaultBrowser(for: ServiceKind.claudeCode.loginURL)
        guard defaultBrowser.family == .safari else { return }
        guard BrowserCookieStore.shared.safariCookieAccessState() == .permissionDenied else { return }

        hasShownSafariAccessPrompt = true

        let strings = AppStrings(language: settings.appLanguage)
        let alert = NSAlert()
        alert.messageText = strings.safariAccessAlertTitle
        alert.informativeText = strings.safariAccessAlertMessage
        alert.addButton(withTitle: strings.openSystemSettings)
        alert.addButton(withTitle: strings.later)
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = BrowserLaunchService.shared.openFullDiskAccessSettings()
        }
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
        let window = makeReportWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reportWindow = window
    }

    private func makeReportWindow() -> NSWindow {
        let view = UsageReportView(historyStore: historyStore, settings: settings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = AppStrings(language: settings.appLanguage).openReport
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        return window
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
