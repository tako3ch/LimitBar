import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore
    @State private var disconnectConfirmationService: ServiceKind?
    @State private var connectionErrorMessage: String?

    var body: some View {
        Form {
            Section(strings.accounts) {
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
            }

            Section(strings.appearance) {
                Picker(strings.language, selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(strings.languageLabel(language)).tag(language)
                    }
                }

                Picker(strings.displayMode, selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(strings.displayModeLabel(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayMode == .minimal ? strings.minimalDescription : strings.normalDescription)
                    .font(.footnote)
                    .foregroundStyle(LimitBarTheme.muted)
            }

            Section(strings.monitoring) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(strings.notificationThreshold)
                        Spacer()
                        Text("\(Int(settings.thresholdPercent))%")
                            .foregroundStyle(LimitBarTheme.muted)
                    }
                    Slider(value: $settings.thresholdPercent, in: 50...100, step: 1)
                }

                Picker(strings.autoRefresh, selection: $settings.refreshInterval) {
                    Text(strings.minutes(1)).tag(TimeInterval(60))
                    Text(strings.minutes(5)).tag(TimeInterval(300))
                    Text(strings.minutes(10)).tag(TimeInterval(600))
                    Text(strings.minutes(15)).tag(TimeInterval(900))
                }
                .onChange(of: settings.refreshInterval) { _, _ in
                    usageStore.rescheduleTimer()
                }

                Toggle(strings.notifications, isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.setNotificationsEnabled($0) }
                ))
                    .disabled(!AppEnvironment.supportsUserNotifications)
                if !AppEnvironment.supportsUserNotifications {
                    Text(strings.notificationsAppOnly)
                        .font(.footnote)
                        .foregroundStyle(LimitBarTheme.muted)
                }
            }

            Section(strings.visibility) {
                Toggle(strings.menuBarItem, isOn: $settings.menuBarEnabled)
                Toggle(strings.floatingWidget, isOn: $settings.widgetEnabled)
                Toggle(strings.alwaysOnTop, isOn: $settings.widgetAlwaysOnTop)
                    .disabled(!settings.widgetEnabled)

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
            }

            Section(strings.system) {
                Toggle(strings.launchAtLogin, isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                    .disabled(!AppEnvironment.supportsLaunchAtLogin)
                if !AppEnvironment.supportsLaunchAtLogin {
                    Text(strings.launchAtLoginAppOnly)
                        .font(.footnote)
                        .foregroundStyle(LimitBarTheme.muted)
                }
                Button(strings.refreshNow) {
                    Task { await usageStore.refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
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
            } catch {
                connectionErrorMessage = error.localizedDescription
            }
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
                    .foregroundStyle(LimitBarTheme.muted)
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

private struct SettingsStrings {
    let appLanguage: AppLanguage

    private var isJapanese: Bool { appLanguage.isJapanese }

    var accounts: String { isJapanese ? "アカウント" : "Accounts" }
    var appearance: String { isJapanese ? "表示" : "Appearance" }
    var monitoring: String { isJapanese ? "監視" : "Monitoring" }
    var visibility: String { isJapanese ? "表示設定" : "Visibility" }
    var system: String { isJapanese ? "システム" : "System" }
    var language: String { isJapanese ? "言語" : "Language" }
    var displayMode: String { isJapanese ? "表示モード" : "Display mode" }
    var minimalDescription: String { isJapanese ? "各サービスのロゴと現在のパーセンテージのみを表示します。" : "Shows only each service logo and the current percentage." }
    var normalDescription: String { isJapanese ? "ロゴ、ステータス、アカウント情報を含む通常表示です。" : "Shows logos, status text, and full account context." }
    var notificationThreshold: String { isJapanese ? "通知しきい値" : "Notification threshold" }
    var autoRefresh: String { isJapanese ? "自動更新" : "Auto refresh" }
    var notifications: String { isJapanese ? "通知" : "Notifications" }
    var notificationsAppOnly: String { isJapanese ? "通知はバンドルされた .app として実行した場合に利用できます。" : "Notifications are available when the app is run from a bundled .app." }
    var menuBarItem: String { isJapanese ? "メニューバー項目" : "Menu bar item" }
    var floatingWidget: String { isJapanese ? "フローティングウィジェット" : "Floating widget" }
    var alwaysOnTop: String { isJapanese ? "常に手前に表示" : "Always on top" }
    var widgetSize: String { isJapanese ? "ウィジェットサイズ" : "Widget size" }
    var widgetPosition: String { isJapanese ? "ウィジェット位置" : "Widget position" }
    var launchAtLogin: String { isJapanese ? "ログイン時に起動" : "Launch at login" }
    var launchAtLoginAppOnly: String { isJapanese ? "ログイン時起動はバンドルされた .app として実行した場合に利用できます。" : "Launch at login is available when the app is run from a bundled .app." }
    var refreshNow: String { isJapanese ? "今すぐ更新" : "Refresh now" }
    var connected: String { isJapanese ? "接続済み" : "Connected" }
    var notConnected: String { isJapanese ? "未接続" : "Not connected" }
    var connect: String { isJapanese ? "接続" : "Connect" }
    var disconnect: String { isJapanese ? "解除" : "Disconnect" }
    var cancel: String { isJapanese ? "キャンセル" : "Cancel" }
    var ok: String { isJapanese ? "OK" : "OK" }
    var connectionErrorTitle: String { isJapanese ? "接続に失敗しました" : "Connection failed" }

    func minutes(_ value: Int) -> String {
        isJapanese ? "\(value)分" : "\(value) min"
    }

    func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .japanese:
            "Japanese"
        case .english:
            "English"
        }
    }

    func displayModeLabel(_ mode: DisplayMode) -> String {
        switch mode {
        case .minimal:
            isJapanese ? "ミニマル" : "Minimal"
        case .normal:
            isJapanese ? "通常" : "Normal"
        }
    }

    func widgetPositionLabel(_ position: WidgetPosition) -> String {
        switch position {
        case .topLeft:
            isJapanese ? "左上" : "Top Left"
        case .topRight:
            isJapanese ? "右上" : "Top Right"
        case .bottomLeft:
            isJapanese ? "左下" : "Bottom Left"
        case .bottomRight:
            isJapanese ? "右下" : "Bottom Right"
        }
    }

    func accountLabel(for service: ServiceKind) -> String {
        switch service {
        case .codex:
            isJapanese ? "OpenAI アカウント" : "OpenAI account"
        case .claudeCode:
            isJapanese ? "Anthropic アカウント" : "Anthropic account"
        }
    }

    func linkAccount(_ serviceName: String) -> String {
        isJapanese ? "\(serviceName) 本体のログイン状態を使って使用状況を監視します。" : "Use the signed-in desktop session for \(serviceName) usage monitoring."
    }

    func disconnectTitle(_ serviceName: String) -> String {
        isJapanese ? "\(serviceName) の接続を解除しますか？" : "Disconnect \(serviceName)?"
    }

    func disconnectMessage(_ serviceName: String) -> String {
        isJapanese ? "\(serviceName) のローカル監視を停止します。アプリ本体のログイン状態はそのまま残ります。" : "This stops local monitoring for \(serviceName) and keeps the desktop login session intact."
    }
}
