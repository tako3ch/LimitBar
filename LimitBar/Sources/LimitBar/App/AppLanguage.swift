import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }

    var isJapanese: Bool {
        switch self {
        case .japanese:
            true
        case .english:
            false
        }
    }

    static func fromSystemLocale() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? ""
        return preferred.hasPrefix("ja") ? .japanese : .english
    }

    static func defaultValue() -> AppLanguage {
        fromSystemLocale()
    }
}

struct AppStrings {
    let language: AppLanguage

    private var isJapanese: Bool { language.isJapanese }

    var appTitle: String { "LimitBar" }
    var setup: String { isJapanese ? "設定" : "Setup" }
    var minimalMode: String { isJapanese ? "ミニマルモード" : "Minimal mode" }
    var usagePulseDescription: String {
        isJapanese ? "Codex と Claude Code の使用状況を表示" : "Usage pulse for Codex and Claude Code"
    }
    var connectService: String { isJapanese ? "サービスを接続" : "Connect a service" }
    var connectServiceDescription: String {
        isJapanese
            ? "設定画面から Codex または Claude Code のアカウントを連携してください。"
            : "Open Settings to link your Codex or Claude Code account."
    }
    var connectServicesWidget: String {
        isJapanese
            ? "設定で Codex または Claude Code を接続"
            : "Connect Codex or Claude Code in Settings"
    }
    var quitApp: String { isJapanese ? "アプリを終了する" : "Quit App" }
    var updatedPrefix: String { isJapanese ? "更新" : "Updated" }
    var openReport: String { isJapanese ? "使用量レポート" : "Usage Report" }
}
