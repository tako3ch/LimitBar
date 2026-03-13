import SwiftUI

enum LimitBarTheme {
    static let background = Color.white.opacity(0.08)
    static let elevatedBackground = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.12)
    static let muted = Color.white.opacity(0.55)
    static let strongText = Color.white.opacity(0.94)
    static let accent = Color(red: 110 / 255, green: 158 / 255, blue: 138 / 255) // #6e9e8a
    static let warning = Color(red: 0.89, green: 0.78, blue: 0.36)
    static let high = Color(red: 0.88, green: 0.56, blue: 0.28)
    static let danger = Color(red: 0.87, green: 0.44, blue: 0.42)
    static let success = Color(red: 0.58, green: 0.78, blue: 0.67)
    static let weeklyText = Color(red: 218 / 255, green: 154 / 255, blue: 122 / 255)
    static let canvasTop = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let canvasBottom = Color(red: 0.05, green: 0.05, blue: 0.06)

    static func severityColor(for percent: Double) -> Color {
        if percent > 90 {
            return danger
        }
        if percent > 80 {
            return high
        }
        if percent > 70 {
            return warning
        }
        return strongText
    }

    static func progressColor(for percent: Double, service: ServiceKind) -> Color {
        if percent > 90 {
            return danger
        }
        if percent > 80 {
            return high
        }
        if percent > 70 {
            return warning
        }
        return service.color
    }
}

extension ServiceKind {
    var color: Color {
        switch self {
        case .codex:
            Color(red: 110 / 255, green: 158 / 255, blue: 138 / 255) // #6e9e8a
        case .claudeCode:
            Color(red: 196 / 255, green: 125 / 255, blue: 90 / 255)  // #c47d5a
        }
    }

    var weeklyColor: Color {
        switch self {
        case .codex:
            Color(red: 141 / 255, green: 185 / 255, blue: 167 / 255) // lighter codex tone
        case .claudeCode:
            Color(red: 218 / 255, green: 154 / 255, blue: 122 / 255) // lighter claude tone
        }
    }
}

extension UsageSnapshot {
    var tint: Color {
        switch status {
        case .normal:
            service.color
        case .warning:
            LimitBarTheme.warning
        case .high:
            LimitBarTheme.high
        case .limitNear:
            LimitBarTheme.danger
        case .resetDetected:
            LimitBarTheme.success
        }
    }
}

extension UsageStatus {
    func tint(for service: ServiceKind) -> Color {
        switch self {
        case .normal:
            service.color
        case .warning:
            LimitBarTheme.warning
        case .high:
            LimitBarTheme.high
        case .limitNear:
            LimitBarTheme.danger
        case .resetDetected:
            LimitBarTheme.success
        }
    }

    var percentageTint: Color {
        switch self {
        case .normal, .resetDetected:
            LimitBarTheme.strongText
        case .warning:
            LimitBarTheme.warning
        case .high:
            LimitBarTheme.high
        case .limitNear:
            LimitBarTheme.danger
        }
    }
}
