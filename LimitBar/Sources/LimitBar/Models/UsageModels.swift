import Foundation

enum ServiceKind: String, CaseIterable, Identifiable, Codable {
    case codex
    case claudeCode

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .codex: "C"
        case .claudeCode: "CC"
        }
    }

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    var logoText: String {
        switch self {
        case .codex: "C"
        case .claudeCode: "CC"
        }
    }

    var accountLabel: String {
        switch self {
        case .codex: "OpenAI account"
        case .claudeCode: "Anthropic account"
        }
    }

    var symbolName: String {
        switch self {
        case .codex: "sparkles.square.filled.on.square"
        case .claudeCode: "bolt.horizontal.circle.fill"
        }
    }
}

enum UsageStatus: String, Codable {
    case normal
    case warning
    case limitNear = "limit_near"
    case resetDetected = "reset_detected"

    var label: String {
        switch self {
        case .normal: "normal"
        case .warning: "warning"
        case .limitNear: "limit near"
        case .resetDetected: "reset detected"
        }
    }
}

struct UsageSnapshot: Identifiable, Equatable, Codable {
    let service: ServiceKind
    let usedPercent: Double
    let status: UsageStatus
    let lastUpdated: Date
    let details: String?

    var id: ServiceKind { service }
    var clampedPercent: Double { min(max(usedPercent, 0), 100) }
}

enum WidgetSize: String, CaseIterable, Codable, Identifiable {
    case small
    case medium

    var id: String { rawValue }
}

enum WidgetPosition: String, CaseIterable, Codable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }
}

enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    case minimal
    case normal

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}
