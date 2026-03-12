import SwiftUI

enum LimitBarTheme {
    static let background = Color.white.opacity(0.08)
    static let elevatedBackground = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.12)
    static let muted = Color.white.opacity(0.55)
    static let strongText = Color.white.opacity(0.94)
    static let accent = Color(red: 0.72, green: 0.76, blue: 0.82)
    static let warning = Color(red: 0.85, green: 0.67, blue: 0.42)
    static let danger = Color(red: 0.87, green: 0.44, blue: 0.42)
    static let success = Color(red: 0.58, green: 0.78, blue: 0.67)
    static let canvasTop = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let canvasBottom = Color(red: 0.05, green: 0.05, blue: 0.06)
}

extension UsageStatus {
    var tint: Color {
        switch self {
        case .normal:
            LimitBarTheme.accent
        case .warning:
            LimitBarTheme.warning
        case .limitNear:
            LimitBarTheme.danger
        case .resetDetected:
            LimitBarTheme.success
        }
    }
}
