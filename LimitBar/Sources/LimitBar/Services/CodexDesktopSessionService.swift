import AppKit
import Foundation

enum CodexDesktopInstallationState: Sendable {
    case installed
    case notInstalled
}

struct CodexDesktopSessionService: Sendable {
    static let shared = CodexDesktopSessionService()

    func installationState() -> CodexDesktopInstallationState {
        hasCLIExecutable() || hasCodexAppBundle() || FileManager.default.fileExists(atPath: authDirectoryURL.path)
            ? .installed
            : .notInstalled
    }

    func detectSession() throws -> LocalAccountSession {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: authFileURL.path) else {
            if installationState() == .notInstalled {
                throw UsageProviderError.localClientNotInstalled(.codex, clientName: "Codex app or CLI")
            }
            throw UsageProviderError.missingLocalSession(.codex)
        }

        let data = try Data(contentsOf: authFileURL)
        let auth = try JSONDecoder().decode(CodexAuthFile.self, from: data)

        guard let accessToken = auth.tokens.accessToken, !accessToken.isEmpty else {
            throw UsageProviderError.missingLocalSession(.codex)
        }

        let profile = LocalAccountSessionDetector.decodeJWTProfile(from: auth.tokens.idToken)
        let labelParts = [profile?.email, profile?.planType?.capitalized].compactMap { $0 }
        let label = labelParts.isEmpty ? ServiceKind.codex.accountLabel : labelParts.joined(separator: " • ")

        return LocalAccountSession(
            service: .codex,
            label: label,
            bearerToken: accessToken,
            cookies: [],
            organizationID: nil
        )
    }

    private var authDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex")
    }

    private var authFileURL: URL {
        authDirectoryURL.appending(path: "auth.json")
    }

    private func hasCLIExecutable() -> Bool {
        let fileManager = FileManager.default
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let candidatePaths = pathEntries.map { URL(fileURLWithPath: $0).appending(path: "codex").path } + [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]

        return candidatePaths.contains { fileManager.isExecutableFile(atPath: $0) }
    }

    private func hasCodexAppBundle() -> Bool {
        let fileManager = FileManager.default
        let candidatePaths = [
            "/Applications/Codex.app",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications/Codex.app"
        ]

        return candidatePaths.contains { fileManager.fileExists(atPath: $0) }
            || workspaceHasCodexApp()
    }

    private func workspaceHasCodexApp() -> Bool {
        let bundleIdentifiers = [
            "com.openai.codex",
            "com.openai.chatgpt.codex"
        ]

        return bundleIdentifiers.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }
}
