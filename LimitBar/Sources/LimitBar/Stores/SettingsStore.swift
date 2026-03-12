import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var thresholdPercent: Double { didSet { save("thresholdPercent", value: thresholdPercent) } }
    @Published var refreshInterval: TimeInterval { didSet { save("refreshInterval", value: refreshInterval) } }
    @Published var menuBarEnabled: Bool { didSet { save("menuBarEnabled", value: menuBarEnabled) } }
    @Published var widgetEnabled: Bool { didSet { save("widgetEnabled", value: widgetEnabled) } }
    @Published var widgetAlwaysOnTop: Bool { didSet { save("widgetAlwaysOnTop", value: widgetAlwaysOnTop) } }
    @Published var launchAtLogin: Bool {
        didSet {
            save("launchAtLogin", value: launchAtLogin)
            LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        }
    }
    @Published var notificationsEnabled: Bool { didSet { save("notificationsEnabled", value: notificationsEnabled) } }
    @Published var widgetSize: WidgetSize {
        didSet {
            save("widgetSize", value: widgetSize.rawValue)
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
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        let storedSize = defaults.string(forKey: "widgetSize") ?? WidgetSize.small.rawValue
        widgetSize = WidgetSize(rawValue: storedSize) ?? .small
    }

    private func save(_ key: String, value: Any) {
        defaults.set(value, forKey: key)
    }
}
