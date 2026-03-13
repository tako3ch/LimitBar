import Foundation

extension Bundle {
    /// app bundle の Contents/Resources/ からリソースバンドルを探す
    static let moduleResources: Bundle = {
        let bundleName = "LimitBar_LimitBar"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,                              // .app/Contents/Resources/
            Bundle(for: BundleResourceLocator.self).resourceURL, // 開発ビルド
            Bundle.main.bundleURL,                               // fallback
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(bundleName + ".bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return Bundle.main
    }()
}

private final class BundleResourceLocator {}
