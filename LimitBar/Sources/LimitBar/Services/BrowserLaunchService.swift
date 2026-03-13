import AppKit

struct BrowserLaunchTarget: Sendable {
    enum Family: Sendable {
        case safari
        case chromium
        case other
    }

    let family: Family
    let bundleIdentifier: String?
    let displayName: String
    let applicationURL: URL?
}

@MainActor
struct BrowserLaunchService {
    static let shared = BrowserLaunchService()

    private let workspace = NSWorkspace.shared

    func openDefaultBrowser(for url: URL) -> BrowserLaunchTarget {
        let target = defaultBrowser(for: url)

        if let applicationURL = target.applicationURL {
            workspace.open([url], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            workspace.open(url)
        }

        return target
    }

    @discardableResult
    func openFullDiskAccessSettings() -> Bool {
        let fullDiskAccessURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!
        if workspace.open(fullDiskAccessURL) {
            return true
        }

        let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")!
        return workspace.open(privacySettingsURL)
    }

    func defaultBrowser(for url: URL) -> BrowserLaunchTarget {
        let applicationURL = workspace.urlForApplication(toOpen: url)
        let bundleIdentifier = applicationURL
            .flatMap(Bundle.init(url:))
            .flatMap(\.bundleIdentifier)

        let family = browserFamily(for: bundleIdentifier)
        let displayName = applicationURL
            .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String }
            ?? displayName(for: family, bundleIdentifier: bundleIdentifier)

        return BrowserLaunchTarget(
            family: family,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )
    }

    private func browserFamily(for bundleIdentifier: String?) -> BrowserLaunchTarget.Family {
        guard let bundleIdentifier else { return .other }
        if bundleIdentifier == "com.apple.Safari" {
            return .safari
        }
        if chromiumBundleIdentifiers.contains(bundleIdentifier) {
            return .chromium
        }
        return .other
    }

    private func displayName(
        for family: BrowserLaunchTarget.Family,
        bundleIdentifier: String?
    ) -> String {
        switch family {
        case .safari:
            return "Safari"
        case .chromium:
            return "Chromium browser"
        case .other:
            return bundleIdentifier ?? "default browser"
        }
    }

    private var chromiumBundleIdentifiers: Set<String> {
        [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium",
            "com.brave.Browser",
            "com.brave.Browser.beta",
            "com.brave.Browser.nightly",
            "com.microsoft.edgemac",
            "com.microsoft.edgemac.Dev",
            "com.microsoft.edgemac.Beta",
            "company.thebrowser.Browser",
            "company.thebrowser.Browser.beta"
        ]
    }
}
