import Foundation

enum AppEnvironment {
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var supportsLaunchAtLogin: Bool { isBundledApp }
    static var supportsUserNotifications: Bool { isBundledApp }
    static var supportsUpdates: Bool { isBundledApp }
}
