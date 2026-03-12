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
    @Published var launchAtLogin: Bool
    @Published var notificationsEnabled: Bool
    @Published var widgetSize: WidgetSize {
        didSet {
            save("widgetSize", value: widgetSize.rawValue)
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            save("displayMode", value: displayMode.rawValue)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        thresholdPercent = defaults.object(forKey: "thresholdPercent") as? Double ?? 90
        refreshInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 300
        menuBarEnabled = defaults.object(forKey: "menuBarEnabled") as? Bool ?? true
        widgetEnabled = defaults.object(forKey: "widgetEnabled") as? Bool ?? true
        widgetAlwaysOnTop = defaults.object(forKey: "widgetAlwaysOnTop") as? Bool ?? false
        codexConnected = defaults.object(forKey: "codexConnected") as? Bool ?? true
        claudeConnected = defaults.object(forKey: "claudeConnected") as? Bool ?? true
        let storedLaunchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        launchAtLogin = AppEnvironment.supportsLaunchAtLogin ? storedLaunchAtLogin : false
        let storedNotificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        notificationsEnabled = AppEnvironment.supportsUserNotifications ? storedNotificationsEnabled : false
        let storedSize = defaults.string(forKey: "widgetSize") ?? WidgetSize.small.rawValue
        widgetSize = WidgetSize(rawValue: storedSize) ?? .small
        let storedDisplayMode = defaults.string(forKey: "displayMode") ?? DisplayMode.normal.rawValue
        displayMode = DisplayMode(rawValue: storedDisplayMode) ?? .normal

        if !AppEnvironment.supportsLaunchAtLogin && storedLaunchAtLogin {
            defaults.set(false, forKey: "launchAtLogin")
        }
        if !AppEnvironment.supportsUserNotifications && storedNotificationsEnabled {
            defaults.set(false, forKey: "notificationsEnabled")
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
        switch service {
        case .codex:
            codexConnected = isConnected
        case .claudeCode:
            claudeConnected = isConnected
        }
    }

    var connectedServices: [ServiceKind] {
        ServiceKind.allCases.filter(isConnected)
    }

    private func save(_ key: String, value: Any) {
        defaults.set(value, forKey: key)
    }
}
