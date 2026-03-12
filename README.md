# LimitBar

Minimal macOS menu bar monitor for Codex and Claude Code usage.

## Open

- Open `Package.swift` in Xcode.
- Run the `LimitBar` executable target on macOS.
- `Launch at login` is disabled in this mode because Xcode runs the package as a plain executable, not a bundled `.app`.

## Build App Bundle

- Run `chmod +x scripts/build_app.sh scripts/build_dmg.sh` once.
- Run `./scripts/build_app.sh` to create `dist/LimitBar.app`.
- Run `./scripts/build_dmg.sh` to create `dist/LimitBar.dmg`.
- Override metadata if needed: `BUNDLE_ID=com.example.LimitBar VERSION=1.0.0 BUILD_NUMBER=1 ./scripts/build_app.sh`
- Default signing is ad-hoc via `SIGN_IDENTITY=-`. For Developer ID signing, pass `SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"`.

The generated `.app` sets `LSUIElement=true`, so it behaves like a menu bar app without a Dock icon.

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
