import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var thresholdPercent: Double { didSet { save("thresholdPercent", value: thresholdPercent) } }
    @Published var refreshInterval: TimeInterval { didSet { save("refreshInterval", value: refreshInterval) } }
    @Published var menuBarEnabled: Bool { didSet { save("menuBarEnabled", value: menuBarEnabled) } }
    @Published var widgetEnabled: Bool { didSet { save("widgetEnabled", value: widgetEnabled) } }
    @Published var widgetAlwaysOnTop: Bool { didSet { save("widgetAlwaysOnTop", value: widgetAlwaysOnTop) } }
    @Published var codexConnected: Bool { didSet { save("codexConnected", value: codexConnected) } }
    @Published var claudeConnected: Bool { didSet { save("claudeConnected", value: claudeConnected) } }
    @Published var codexAccountLabel: String? { didSet { saveOptional("codexAccountLabel", value: codexAccountLabel) } }
    @Published var claudeAccountLabel: String? { didSet { saveOptional("claudeAccountLabel", value: claudeAccountLabel) } }
    @Published var launchAtLogin: Bool
    @Published var notificationsEnabled: Bool
    var appLanguage: AppLanguage { AppLanguage.fromSystemLocale() }
    @Published var widgetSize: WidgetSize {
        didSet {
            save("widgetSize", value: widgetSize.rawValue)
        }
    }
    @Published var widgetPosition: WidgetPosition {
        didSet {
            save("widgetPosition", value: widgetPosition.rawValue)
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            save("displayMode", value: displayMode.rawValue)
        }
    }
    @Published var widgetOpacity: Double {
        didSet { save("widgetOpacity", value: widgetOpacity) }
    }
    @Published var widgetServiceOrder: [String] {
        didSet { defaults.set(widgetServiceOrder, forKey: "widgetServiceOrder") }
    }

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        thresholdPercent = defaults.object(forKey: "thresholdPercent") as? Double ?? 90
        refreshInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 900
        menuBarEnabled = defaults.object(forKey: "menuBarEnabled") as? Bool ?? true
        widgetEnabled = defaults.object(forKey: "widgetEnabled") as? Bool ?? true
        widgetAlwaysOnTop = defaults.object(forKey: "widgetAlwaysOnTop") as? Bool ?? false
        codexAccountLabel = defaults.string(forKey: "codexAccountLabel")
        claudeAccountLabel = defaults.string(forKey: "claudeAccountLabel")
        let detector = LocalAccountSessionDetector.shared
        let storedCodexConnected = defaults.object(forKey: "codexConnected") as? Bool
        let storedClaudeConnected = defaults.object(forKey: "claudeConnected") as? Bool
        let hasCodexSession = detector.hasSession(for: .codex)
        let hasClaudeSession = detector.hasSession(for: .claudeCode)
        codexConnected = (storedCodexConnected ?? hasCodexSession) && hasCodexSession
        claudeConnected = (storedClaudeConnected ?? hasClaudeSession) && hasClaudeSession
        let storedLaunchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        launchAtLogin = AppEnvironment.supportsLaunchAtLogin ? storedLaunchAtLogin : false
        let storedNotificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        notificationsEnabled = AppEnvironment.supportsUserNotifications ? storedNotificationsEnabled : false
        let storedSize = defaults.string(forKey: "widgetSize") ?? WidgetSize.small.rawValue
        widgetSize = WidgetSize(rawValue: storedSize) ?? .small
        let storedWidgetPosition = defaults.string(forKey: "widgetPosition") ?? WidgetPosition.topRight.rawValue
        widgetPosition = WidgetPosition(rawValue: storedWidgetPosition) ?? .topRight
        let storedDisplayMode = defaults.string(forKey: "displayMode") ?? DisplayMode.normal.rawValue
        displayMode = DisplayMode(rawValue: storedDisplayMode) ?? .normal
        widgetOpacity = defaults.object(forKey: "widgetOpacity") as? Double ?? 0.85
        widgetServiceOrder = (defaults.array(forKey: "widgetServiceOrder") as? [String]) ?? ["codex", "claudeCode"]

        if !AppEnvironment.supportsLaunchAtLogin && storedLaunchAtLogin {
            defaults.set(false, forKey: "launchAtLogin")
        }
        if !AppEnvironment.supportsUserNotifications && storedNotificationsEnabled {
            defaults.set(false, forKey: "notificationsEnabled")
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
        save("launchAtLogin", value: nextValue)
        if AppEnvironment.supportsLaunchAtLogin {
            LaunchAtLoginManager.shared.setEnabled(nextValue)
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        let nextValue = AppEnvironment.supportsUserNotifications ? isEnabled : false
        guard notificationsEnabled != nextValue else { return }
        notificationsEnabled = nextValue
        save("notificationsEnabled", value: nextValue)
    }

    func isConnected(_ service: ServiceKind) -> Bool {
        switch service {
        case .codex:
            codexConnected
        case .claudeCode:
            claudeConnected
        }
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
        switch service {
        case .codex:
            codexConnected = true
            codexAccountLabel = normalizedLabel(from: session.label, service: service)
        case .claudeCode:
            claudeConnected = true
            claudeAccountLabel = normalizedLabel(from: session.label, service: service)
        }
    }

    func disconnect(_ service: ServiceKind) {
        switch service {
        case .codex:
            codexConnected = false
            codexAccountLabel = nil
        case .claudeCode:
            claudeConnected = false
            claudeAccountLabel = nil
            try? ClaudeWebSessionStore.shared.deleteSession()
        }
    }

    var connectedServices: [ServiceKind] {
        ServiceKind.allCases.filter(isConnected)
    }

    func accountLabel(for service: ServiceKind) -> String? {
        switch service {
        case .codex:
            codexAccountLabel
        case .claudeCode:
            claudeAccountLabel
        }
    }

    private func save(_ key: String, value: Any) {
        defaults.set(value, forKey: key)
    }

    private func saveOptional(_ key: String, value: String?) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func normalizedLabel(from label: String, service: ServiceKind) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? service.accountLabel : trimmed
    }
}
