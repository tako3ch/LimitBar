import Foundation

struct AppVersion {
    let marketingVersion: String
    let buildNumber: String

    var displayString: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }

    static let current = loadCurrentVersion()

    private static func loadCurrentVersion() -> AppVersion {
        if
            let infoDictionary = Bundle.main.infoDictionary,
            let marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String,
            let buildNumber = infoDictionary["CFBundleVersion"] as? String
        {
            return AppVersion(marketingVersion: marketingVersion, buildNumber: buildNumber)
        }

        guard
            let url = Bundle.module.url(forResource: "AppVersion", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let rawValue = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let marketingVersion = rawValue["MarketingVersion"] as? String,
            let buildNumber = rawValue["BuildNumber"] as? String
        else {
            return AppVersion(marketingVersion: "0.0.0", buildNumber: "0")
        }

        return AppVersion(marketingVersion: marketingVersion, buildNumber: buildNumber)
    }
}
