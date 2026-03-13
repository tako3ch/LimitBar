import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var thresholdPercent: Double { didSet { save(.thresholdPercent, value: thresholdPercent) } }
    @Published var refreshInterval: TimeInterval { didSet { save(.refreshInterval, value: refreshInterval) } }
    @Published var menuBarEnabled: Bool { didSet { save(.menuBarEnabled, value: menuBarEnabled) } }
    @Published var widgetEnabled: Bool { didSet { save(.widgetEnabled, value: widgetEnabled) } }
    @Published var widgetAlwaysOnTop: Bool { didSet { save(.widgetAlwaysOnTop, value: widgetAlwaysOnTop) } }
    @Published var codexConnected: Bool { didSet { save(.codexConnected, value: codexConnected) } }
    @Published var claudeConnected: Bool { didSet { save(.claudeConnected, value: claudeConnected) } }
    @Published var codexAccountLabel: String? { didSet { saveOptional(.codexAccountLabel, value: codexAccountLabel) } }
    @Published var claudeAccountLabel: String? { didSet { saveOptional(.claudeAccountLabel, value: claudeAccountLabel) } }
    @Published var launchAtLogin: Bool
    @Published var notificationsEnabled: Bool
    var appLanguage: AppLanguage { AppLanguage.fromSystemLocale() }
    @Published var widgetSize: WidgetSize {
        didSet {
            save(.widgetSize, value: widgetSize.rawValue)
        }
    }
    @Published var widgetPosition: WidgetPosition {
        didSet {
            save(.widgetPosition, value: widgetPosition.rawValue)
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            save(.displayMode, value: displayMode.rawValue)
        }
    }
    @Published var widgetOpacity: Double {
        didSet { save(.widgetOpacity, value: widgetOpacity) }
    }
    @Published var widgetServiceOrder: [String] {
        didSet { defaults.set(widgetServiceOrder, forKey: Key.widgetServiceOrder.rawValue) }
    }
    @Published var showClaudeWeeklyLimitInWidget: Bool {
        didSet { save(.showClaudeWeeklyLimitInWidget, value: showClaudeWeeklyLimitInWidget) }
    }
    @Published var showCodexWeeklyLimitInWidget: Bool {
        didSet { save(.showCodexWeeklyLimitInWidget, value: showCodexWeeklyLimitInWidget) }
    }

    private let defaults: UserDefaults

    private enum Key: String {
        case thresholdPercent
        case refreshInterval
        case menuBarEnabled
        case widgetEnabled
        case widgetAlwaysOnTop
        case codexConnected
        case claudeConnected
        case codexAccountLabel
        case claudeAccountLabel
        case launchAtLogin
        case notificationsEnabled
        case widgetSize
        case widgetPosition
        case displayMode
        case widgetOpacity
        case widgetServiceOrder
        case showClaudeWeeklyLimitInWidget
        case showCodexWeeklyLimitInWidget
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        thresholdPercent = defaults.object(forKey: Key.thresholdPercent.rawValue) as? Double ?? 90
        refreshInterval = defaults.object(forKey: Key.refreshInterval.rawValue) as? Double ?? 900
        menuBarEnabled = defaults.object(forKey: Key.menuBarEnabled.rawValue) as? Bool ?? true
        widgetEnabled = defaults.object(forKey: Key.widgetEnabled.rawValue) as? Bool ?? true
        widgetAlwaysOnTop = defaults.object(forKey: Key.widgetAlwaysOnTop.rawValue) as? Bool ?? false
        codexAccountLabel = defaults.string(forKey: Key.codexAccountLabel.rawValue)
        claudeAccountLabel = defaults.string(forKey: Key.claudeAccountLabel.rawValue)
        let detector = LocalAccountSessionDetector.shared
        let storedCodexConnected = defaults.object(forKey: Key.codexConnected.rawValue) as? Bool
        let storedClaudeConnected = defaults.object(forKey: Key.claudeConnected.rawValue) as? Bool
        let hasCodexSession = detector.hasSession(for: .codex)
        let hasClaudeSession = detector.hasSession(for: .claudeCode)
        codexConnected = (storedCodexConnected ?? hasCodexSession) && hasCodexSession
        claudeConnected = (storedClaudeConnected ?? hasClaudeSession) && hasClaudeSession
        let storedLaunchAtLogin = defaults.object(forKey: Key.launchAtLogin.rawValue) as? Bool ?? false
        launchAtLogin = AppEnvironment.supportsLaunchAtLogin ? storedLaunchAtLogin : false
        let storedNotificationsEnabled = defaults.object(forKey: Key.notificationsEnabled.rawValue) as? Bool ?? true
        notificationsEnabled = AppEnvironment.supportsUserNotifications ? storedNotificationsEnabled : false
        let storedSize = defaults.string(forKey: Key.widgetSize.rawValue) ?? WidgetSize.small.rawValue
        widgetSize = WidgetSize(rawValue: storedSize) ?? .small
        let storedWidgetPosition = defaults.string(forKey: Key.widgetPosition.rawValue) ?? WidgetPosition.topRight.rawValue
        widgetPosition = WidgetPosition(rawValue: storedWidgetPosition) ?? .topRight
        let storedDisplayMode = defaults.string(forKey: Key.displayMode.rawValue) ?? DisplayMode.normal.rawValue
        displayMode = DisplayMode(rawValue: storedDisplayMode) ?? .normal
        widgetOpacity = defaults.object(forKey: Key.widgetOpacity.rawValue) as? Double ?? 0.85
        widgetServiceOrder = (defaults.array(forKey: Key.widgetServiceOrder.rawValue) as? [String]) ?? [ServiceKind.codex.rawValue, ServiceKind.claudeCode.rawValue]
        showClaudeWeeklyLimitInWidget = defaults.object(forKey: Key.showClaudeWeeklyLimitInWidget.rawValue) as? Bool ?? false
        showCodexWeeklyLimitInWidget = defaults.object(forKey: Key.showCodexWeeklyLimitInWidget.rawValue) as? Bool ?? false

        if !AppEnvironment.supportsLaunchAtLogin && storedLaunchAtLogin {
            defaults.set(false, forKey: Key.launchAtLogin.rawValue)
        }
        if !AppEnvironment.supportsUserNotifications && storedNotificationsEnabled {
            defaults.set(false, forKey: Key.notificationsEnabled.rawValue)
        }
        if !codexConnected {
            codexAccountLabel = nil
        }
        if !claudeConnected {
            claudeAccountLabel = nil
        }
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        let nextValue = AppEnvironment.supportsLaunchAtLogin ? isEnabled : false
        guard launchAtLogin != nextValue else { return }
        launchAtLogin = nextValue
        save(.launchAtLogin, value: nextValue)
        if AppEnvironment.supportsLaunchAtLogin {
            LaunchAtLoginManager.shared.setEnabled(nextValue)
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        let nextValue = AppEnvironment.supportsUserNotifications ? isEnabled : false
        guard notificationsEnabled != nextValue else { return }
        notificationsEnabled = nextValue
        save(.notificationsEnabled, value: nextValue)
    }

    func isConnected(_ service: ServiceKind) -> Bool {
        serviceState(for: service).isConnected
    }

    func setConnection(_ service: ServiceKind, isConnected: Bool) {
        if isConnected {
            try? connect(service)
        } else {
            disconnect(service)
        }
    }

    func connect(_ service: ServiceKind) throws {
        let session = try LocalAccountSessionDetector.shared.detectSession(for: service)
        applyConnectedSession(session)
    }

    func applyConnectedSession(_ session: LocalAccountSession) {
        let service = session.service
        setConnectionState(
            for: service,
            isConnected: true,
            accountLabel: normalizedLabel(from: session.label, service: service)
        )
    }

    func disconnect(_ service: ServiceKind) {
        setConnectionState(for: service, isConnected: false, accountLabel: nil)
        if service == .claudeCode {
            try? ClaudeWebSessionStore.shared.deleteSession()
        }
    }

    var connectedServices: [ServiceKind] {
        ServiceKind.allCases.filter(isConnected)
    }

    func accountLabel(for service: ServiceKind) -> String? {
        serviceState(for: service).accountLabel
    }

    func showsWeeklyLimitInWidget(for service: ServiceKind) -> Bool {
        switch service {
        case .codex:
            showCodexWeeklyLimitInWidget
        case .claudeCode:
            showClaudeWeeklyLimitInWidget
        }
    }

    private func setConnectionState(for service: ServiceKind, isConnected: Bool, accountLabel: String?) {
        switch service {
        case .codex:
            codexConnected = isConnected
            codexAccountLabel = accountLabel
        case .claudeCode:
            claudeConnected = isConnected
            claudeAccountLabel = accountLabel
        }
    }

    private func serviceState(for service: ServiceKind) -> (isConnected: Bool, accountLabel: String?) {
        switch service {
        case .codex:
            (codexConnected, codexAccountLabel)
        case .claudeCode:
            (claudeConnected, claudeAccountLabel)
        }
    }

    private func save(_ key: Key, value: Any) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func saveOptional(_ key: Key, value: String?) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    private func normalizedLabel(from label: String, service: ServiceKind) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? service.accountLabel : trimmed
    }
}
