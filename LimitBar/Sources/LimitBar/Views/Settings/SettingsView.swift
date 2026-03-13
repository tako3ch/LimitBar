import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore
    var onCheckForUpdates: (() -> Void)?
    @State private var disconnectConfirmationService: ServiceKind?
    @State private var connectionErrorMessage: String?

    var body: some View {
        Form {

            // MARK: アカウント
            Section {
                VStack(spacing: 12) {
                    ForEach(ServiceKind.allCases) { service in
                        AccountIntegrationRow(
                            service: service,
                            isConnected: settings.isConnected(service),
                            accountLabel: settings.accountLabel(for: service),
                            strings: strings,
                            action: { toggleConnection(for: service) }
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label(strings.accounts, systemImage: "person.2")
            } footer: {
                Text(strings.accountsFooter)
            }

            // MARK: 表示モード
            Section {
                Picker(strings.displayMode, selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(strings.displayModeLabel(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayMode == .minimal ? strings.minimalDescription : strings.normalDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Label(strings.displayModeSection, systemImage: "rectangle.on.rectangle")
            }

            // MARK: ウィジェット
            Section {
                Toggle(strings.floatingWidget, isOn: $settings.widgetEnabled)

                Picker(strings.widgetSize, selection: $settings.widgetSize) {
                    Text("S").tag(WidgetSize.small)
                    Text("M").tag(WidgetSize.medium)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)

                Picker(strings.widgetPosition, selection: $settings.widgetPosition) {
                    ForEach(WidgetPosition.allCases) { position in
                        Text(strings.widgetPositionLabel(position)).tag(position)
                    }
                }
                .disabled(!settings.widgetEnabled)

                Toggle(strings.alwaysOnTop, isOn: $settings.widgetAlwaysOnTop)
                    .disabled(!settings.widgetEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(strings.widgetOpacity)
                        Spacer()
                        Text("\(Int(settings.widgetOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.widgetOpacity, in: 0.3...1.0, step: 0.05)
                }
                .disabled(!settings.widgetEnabled)

                Picker(strings.widgetOrder, selection: Binding(
                    get: { settings.widgetServiceOrder.first == "codex" },
                    set: { codexFirst in
                        settings.widgetServiceOrder = codexFirst
                            ? ["codex", "claudeCode"]
                            : ["claudeCode", "codex"]
                    }
                )) {
                    Text(strings.widgetOrderCodexFirst).tag(true)
                    Text(strings.widgetOrderClaudeFirst).tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)

                Toggle(strings.showClaudeWeeklyLimitInWidget, isOn: $settings.showClaudeWeeklyLimitInWidget)
                    .disabled(!settings.widgetEnabled)

                Toggle(strings.showCodexWeeklyLimitInWidget, isOn: $settings.showCodexWeeklyLimitInWidget)
                    .disabled(!settings.widgetEnabled)
            } header: {
                Label(strings.widgetSection, systemImage: "macwindow.on.rectangle")
            } footer: {
                Text(strings.widgetFooter)
            }

            // MARK: 通知・更新
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(strings.notificationThreshold)
                        Spacer()
                        Text("\(Int(settings.thresholdPercent))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.thresholdPercent, in: 50...100, step: 1)
                    Text(strings.notificationThresholdDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker(strings.autoRefresh, selection: $settings.refreshInterval) {
                    Text(strings.minutes(1)).tag(TimeInterval(60))
                    Text(strings.minutes(5)).tag(TimeInterval(300))
                    Text(strings.minutes(10)).tag(TimeInterval(600))
                    Text(strings.minutes(15)).tag(TimeInterval(900))
                    Text(strings.minutes(30)).tag(TimeInterval(1800))
                }
                .onChange(of: settings.refreshInterval) { _, _ in
                    usageStore.rescheduleTimer()
                }

                HStack {
                    Toggle(strings.notifications, isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.setNotificationsEnabled($0) }
                    ))
                    .disabled(!AppEnvironment.supportsUserNotifications)

                    Spacer()

                    Button(strings.testNotification) {
                        usageStore.sendTestNotification()
                    }
                    .disabled(!settings.notificationsEnabled || !AppEnvironment.supportsUserNotifications)
                }

                Text(strings.notificationsDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !AppEnvironment.supportsUserNotifications {
                    Text(strings.notificationsAppOnly)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(strings.monitoring, systemImage: "bell.badge")
            }

            // MARK: システム
            Section {
                Toggle(strings.menuBarItem, isOn: $settings.menuBarEnabled)

                Toggle(strings.launchAtLogin, isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                .disabled(!AppEnvironment.supportsLaunchAtLogin)

                if !AppEnvironment.supportsLaunchAtLogin {
                    Text(strings.launchAtLoginAppOnly)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(strings.refreshNow) {
                    Task { await usageStore.refresh() }
                }

                if AppEnvironment.supportsUpdates, let onCheckForUpdates {
                    Button(strings.checkForUpdates) {
                        onCheckForUpdates()
                    }
                }

                HStack {
                    Text(strings.version)
                    Spacer()
                    Text(AppVersion.current.displayString)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Label(strings.system, systemImage: "gearshape")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 540)
        .background(WindowLevelReader(level: .floating))
        .alert(strings.connectionErrorTitle, isPresented: Binding(
            get: { connectionErrorMessage != nil },
            set: { if !$0 { connectionErrorMessage = nil } }
        )) {
            Button(strings.ok, role: .cancel) {}
        } message: {
            Text(connectionErrorMessage ?? "")
        }
        .alert(item: $disconnectConfirmationService) { service in
            Alert(
                title: Text(strings.disconnectTitle(service.displayName)),
                message: Text(strings.disconnectMessage(service.displayName)),
                primaryButton: .destructive(Text(strings.disconnect)) {
                    settings.disconnect(service)
                    usageStore.disconnect(service)
                },
                secondaryButton: .cancel(Text(strings.cancel))
            )
        }
    }

    private var strings: SettingsStrings {
        SettingsStrings(appLanguage: settings.appLanguage)
    }

    private func toggleConnection(for service: ServiceKind) {
        if settings.isConnected(service) {
            disconnectConfirmationService = service
        } else {
            do {
                try settings.connect(service)
                connectionErrorMessage = nil
                Task { await usageStore.refresh() }
            } catch UsageProviderError.localClientNotInstalled(.codex, _) {
                connectionErrorMessage = strings.codexInstallPrompt
            } catch UsageProviderError.missingLocalSession(.codex) {
                connectionErrorMessage = strings.codexLoginPrompt
            } catch UsageProviderError.missingLocalSession(.claudeCode) {
                let launchedBrowser = openClaudeLoginPage()
                connectionErrorMessage = browserPrompt(for: launchedBrowser, service: .claudeCode)
            } catch UsageProviderError.browserDataAccessDenied(let deniedService, let browserName) {
                connectionErrorMessage = strings.browserAccessDenied(serviceName: deniedService.displayName, browserName: browserName)
            } catch {
                connectionErrorMessage = error.localizedDescription
            }
        }
    }

    private func openClaudeLoginPage() -> BrowserLaunchTarget {
        BrowserLaunchService.shared.openDefaultBrowser(for: ServiceKind.claudeCode.loginURL)
    }

    private func browserPrompt(for browser: BrowserLaunchTarget, service: ServiceKind) -> String {
        switch browser.family {
        case .safari:
            if BrowserCookieStore.shared.safariCookieAccessState() == .permissionDenied {
                strings.safariFullDiskAccessPrompt(service.displayName, browserName: browser.displayName)
            } else {
                strings.browserLoginPrompt(service.displayName, browserName: browser.displayName)
            }
        case .chromium:
            strings.browserLoginPrompt(service.displayName, browserName: browser.displayName)
        case .other:
            strings.browserLoginPrompt(service.displayName, browserName: browser.displayName)
        }
    }
}

#Preview("Settings") {
    SettingsView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
}

private struct AccountIntegrationRow: View {
    let service: ServiceKind
    let isConnected: Bool
    let accountLabel: String?
    let strings: SettingsStrings
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ServiceLogoMark(service: service, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(service.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(isConnected ? strings.connected : strings.notConnected)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isConnected ? LimitBarTheme.success : LimitBarTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill((isConnected ? LimitBarTheme.success : LimitBarTheme.warning).opacity(0.14))
                        )
                }

                Text(isConnected ? (accountLabel ?? strings.accountLabel(for: service)) : strings.linkAccount(service.displayName))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isConnected ? strings.disconnect : strings.connect) {
                action()
            }
            .buttonStyle(.borderedProminent)
            .tint(isConnected ? LimitBarTheme.warning : LimitBarTheme.accent)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsStrings {
    let appLanguage: AppLanguage

    private var isJapanese: Bool { appLanguage.isJapanese }

    // セクションヘッダー
    var accounts: String { isJapanese ? "アカウント" : "Accounts" }
    var displayModeSection: String { isJapanese ? "表示モード" : "Display Mode" }
    var widgetSection: String { isJapanese ? "ウィジェット" : "Widget" }
    var monitoring: String { isJapanese ? "通知・更新" : "Notifications & Updates" }
    var system: String { isJapanese ? "システム" : "System" }

    // フッター・説明文
    var accountsFooter: String {
        isJapanese
            ? "ローカルのログインセッションを使って使用状況を取得します。"
            : "Usage is fetched using your local login session."
    }
    var widgetFooter: String {
        isJapanese
            ? "ウィジェットをオフにすると、以下の設定はすべて無効になります。"
            : "When the widget is off, all settings below are disabled."
    }
    var notificationThresholdDescription: String {
        isJapanese
            ? "この使用率を超えたときに通知します。"
            : "You will be notified when usage exceeds this level."
    }

    // 表示モード
    var displayMode: String { isJapanese ? "モード" : "Mode" }
    var minimalDescription: String { isJapanese ? "ロゴと使用率のみをコンパクトに表示します。" : "Shows only the logo and usage percentage." }
    var normalDescription: String { isJapanese ? "ロゴ・ステータス・アカウント情報を表示します。" : "Shows logo, status, and account details." }

    // ウィジェット
    var floatingWidget: String { isJapanese ? "フローティングウィジェット" : "Floating widget" }
    var alwaysOnTop: String { isJapanese ? "常に手前に表示" : "Always on top" }
    var widgetSize: String { isJapanese ? "サイズ" : "Size" }
    var widgetPosition: String { isJapanese ? "位置" : "Position" }
    var widgetOpacity: String { isJapanese ? "背景の透明度" : "Background opacity" }
    var widgetOrder: String { isJapanese ? "表示順" : "Display order" }
    var widgetOrderCodexFirst: String { isJapanese ? "Codex を先に表示" : "Codex first" }
    var widgetOrderClaudeFirst: String { isJapanese ? "Claude Code を先に表示" : "Claude Code first" }
    var showClaudeWeeklyLimitInWidget: String { isJapanese ? "Weekly Limits 表示(Claude Code)" : "Show Weekly Limits (Claude Code)" }
    var showCodexWeeklyLimitInWidget: String { isJapanese ? "Weekly Limits 表示(Codex)" : "Show Weekly Limits (Codex)" }

    // 通知・更新
    var notificationThreshold: String { isJapanese ? "通知しきい値" : "Notification threshold" }
    var autoRefresh: String { isJapanese ? "自動更新の間隔" : "Auto refresh interval" }
    var notifications: String { isJapanese ? "通知を有効にする" : "Enable notifications" }
    var testNotification: String { isJapanese ? "テスト送信" : "Send test" }
    var notificationsDescription: String {
        isJapanese
            ? "使用率がしきい値を超えたとき、または使用量がリセットされたときに通知します。"
            : "Notifies when usage exceeds the threshold or resets."
    }
    var notificationsAppOnly: String {
        isJapanese
            ? "通知は .app として実行したときのみ利用できます。"
            : "Notifications are available when run from a bundled .app."
    }

    // システム
    var menuBarItem: String { isJapanese ? "メニューバーに表示" : "Show in menu bar" }
    var launchAtLogin: String { isJapanese ? "ログイン時に自動起動" : "Launch at login" }
    var launchAtLoginAppOnly: String {
        isJapanese
            ? "自動起動は .app として実行したときのみ利用できます。"
            : "Launch at login is available when run from a bundled .app."
    }
    var refreshNow: String { isJapanese ? "今すぐ更新" : "Refresh now" }
    var checkForUpdates: String { isJapanese ? "アップデートを確認" : "Check for Updates" }
    var version: String { isJapanese ? "バージョン" : "Version" }

    // アカウント関連
    var connected: String { isJapanese ? "接続済み" : "Connected" }
    var notConnected: String { isJapanese ? "未接続" : "Not connected" }
    var connect: String { isJapanese ? "接続" : "Connect" }
    var disconnect: String { isJapanese ? "解除" : "Disconnect" }
    var cancel: String { isJapanese ? "キャンセル" : "Cancel" }
    var ok: String { isJapanese ? "OK" : "OK" }
    var connectionErrorTitle: String { isJapanese ? "接続に失敗しました" : "Connection failed" }
    var codexInstallPrompt: String {
        isJapanese
            ? "Codex の使用量を取得するには、Codex アプリまたは CLI をこの Mac にインストールしてください。インストール後、Codex 側でログインしてから再度接続してください。"
            : "To fetch Codex usage, install the Codex app or CLI on this Mac. After installing, sign in to Codex and then connect again."
    }
    var codexLoginPrompt: String {
        isJapanese
            ? "Codex の使用量を取得するには、Codex アプリまたは CLI でログインしてください。ログイン後に LimitBar へ戻って再度接続してください。"
            : "To fetch Codex usage, sign in through the Codex app or CLI. Then return to LimitBar and connect again."
    }

    func browserLoginPrompt(_ serviceName: String, browserName: String) -> String {
        isJapanese
            ? "\(serviceName) のローカルログインが見つからなかったため、\(browserName) を開きました。ログイン後にアプリへ戻って再度接続してください。"
            : "No local \(serviceName) login was found, so \(browserName) was opened. Sign in, then return and connect again."
    }

    func safariFullDiskAccessPrompt(_ serviceName: String, browserName: String) -> String {
        isJapanese
            ? "\(serviceName) のローカルログインが見つからなかったため、\(browserName) を開きました。Safari ログインを使うには LimitBar にフルディスクアクセスを許可してください。その後、ログインしてアプリへ戻り、もう一度接続してください。"
            : "No local \(serviceName) login was found, so \(browserName) was opened. To use a Safari login, grant LimitBar Full Disk Access, then sign in and return to connect again."
    }

    func browserAccessDenied(serviceName: String, browserName: String) -> String {
        isJapanese
            ? "\(serviceName) は \(browserName) のログイン情報にアクセスできませんでした。macOS の権限制限で Safari データが読めない状態です。必要に応じて LimitBar にフルディスクアクセスを付与するか、Chrome 系ブラウザまたはデスクトップ側ログインを利用してください。"
            : "\(serviceName) could not access \(browserName) login data. macOS is blocking Safari data access. Grant LimitBar Full Disk Access if needed, or use a Chromium-based browser or desktop login instead."
    }

    func minutes(_ value: Int) -> String {
        isJapanese ? "\(value)分ごと" : "Every \(value) min"
    }

    func displayModeLabel(_ mode: DisplayMode) -> String {
        switch mode {
        case .minimal: isJapanese ? "ミニマル" : "Minimal"
        case .normal: isJapanese ? "通常" : "Normal"
        }
    }

    func widgetPositionLabel(_ position: WidgetPosition) -> String {
        switch position {
        case .topLeft: isJapanese ? "左上" : "Top Left"
        case .topRight: isJapanese ? "右上" : "Top Right"
        case .bottomLeft: isJapanese ? "左下" : "Bottom Left"
        case .bottomRight: isJapanese ? "右下" : "Bottom Right"
        }
    }

    func accountLabel(for service: ServiceKind) -> String {
        switch service {
        case .codex: isJapanese ? "OpenAI アカウント" : "OpenAI account"
        case .claudeCode: isJapanese ? "Anthropic アカウント" : "Anthropic account"
        }
    }

    func linkAccount(_ serviceName: String) -> String {
        isJapanese
            ? "\(serviceName) のデスクトップセッションを使って監視します。"
            : "Monitors using the signed-in \(serviceName) desktop session."
    }

    func disconnectTitle(_ serviceName: String) -> String {
        isJapanese ? "\(serviceName) の接続を解除しますか？" : "Disconnect \(serviceName)?"
    }

    func disconnectMessage(_ serviceName: String) -> String {
        isJapanese
            ? "\(serviceName) の監視を停止します。デスクトップのログイン状態はそのまま残ります。"
            : "This stops monitoring for \(serviceName). Your desktop session remains intact."
    }
}
