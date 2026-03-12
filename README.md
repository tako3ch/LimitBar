# LimitBar

Minimal macOS menu bar monitor for Codex and Claude Code usage.

## Open

- Open `Package.swift` in Xcode.
- Run the `LimitBar` executable target on macOS.
- `Launch at login` is disabled in this mode because Xcode runs the package as a plain executable, not a bundled `.app`.

## Current State

- SwiftUI-based macOS app
- `MenuBarExtra` menu bar UI
- Floating glass widget via `NSPanel`
- Mock-driven auto refresh and manual refresh
- Threshold and reset notifications
- Settings persistence via `UserDefaults`

## Swap Mock Providers Later

- Implement real fetching in `LimitBar/Sources/LimitBar/Providers/CodexUsageProvider.swift`
- Implement real fetching in `LimitBar/Sources/LimitBar/Providers/ClaudeCodeUsageProvider.swift`
- Replace `MockUsageProvider` wiring in `LimitBar/Sources/LimitBar/App/AppModel.swift`
