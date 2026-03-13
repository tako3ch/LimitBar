import Foundation

enum AppEnvironment {
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // Gatekeeper の App Translocation により一時パスで実行されているか
    // /private/var/folders/.../AppTranslocation/... で動いている場合は true
    static var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("AppTranslocation")
    }

    static var supportsLaunchAtLogin: Bool { isBundledApp }
    static var supportsUserNotifications: Bool { isBundledApp }
    static var supportsUpdates: Bool { isBundledApp }
}
