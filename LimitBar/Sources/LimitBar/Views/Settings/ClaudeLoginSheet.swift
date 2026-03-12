import SwiftUI
import WebKit

struct ClaudeLoginSheet: View {
    let strings: SettingsStrings
    let onCancel: () -> Void
    let onComplete: () -> Void

    @StateObject private var model: ClaudeLoginFlowModel

    init(strings: SettingsStrings, onCancel: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.strings = strings
        self.onCancel = onCancel
        self.onComplete = onComplete
        _model = StateObject(wrappedValue: ClaudeLoginFlowModel(strings: strings))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(strings.claudeLoginTitle)
                    .font(.system(size: 18, weight: .semibold))
                Text(strings.claudeLoginDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ClaudeLoginWebView(model: model)
                .frame(width: 720, height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12))
                )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                    if let currentURL = model.currentURL {
                        Text(currentURL.absoluteString)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(strings.cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isWorking)
            }
        }
        .padding(20)
        .frame(width: 760)
        .onChange(of: model.didCompleteLogin) { _, completed in
            guard completed else { return }
            onComplete()
        }
        .alert(strings.connectionErrorTitle, isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button(strings.ok, role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

@MainActor
final class ClaudeLoginFlowModel: ObservableObject {
    @Published var statusMessage: String
    @Published var currentURL: URL?
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var didCompleteLogin = false

    private var isPersisting = false
    let strings: SettingsStrings

    init(strings: SettingsStrings) {
        self.strings = strings
        statusMessage = strings.claudeLoginLoading
    }

    func setStatusMessage(_ message: String) {
        statusMessage = message
    }

    func updateCurrentURL(_ url: URL?) {
        currentURL = url
    }

    func inspect(cookieStore: WKHTTPCookieStore) {
        guard !isPersisting, !didCompleteLogin else { return }

        Task { @MainActor in
            let cookies = await cookieStore.allCookies()
            guard cookies.contains(where: { $0.name == "sessionKey" && !$0.value.isEmpty }) else {
                return
            }

            isPersisting = true
            isWorking = true
            statusMessage = strings.claudeLoginSaving

            do {
                _ = try await ClaudeWebLoginService.shared.persistSession(from: cookies)
                statusMessage = strings.claudeLoginConnected
                didCompleteLogin = true
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = strings.claudeLoginWaiting
            }

            isWorking = false
            isPersisting = false
        }
    }
}

private struct ClaudeLoginWebView: NSViewRepresentable {
    @ObservedObject var model: ClaudeLoginFlowModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = ClaudeWebLoginService.userAgent
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: ServiceKind.claudeCode.loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let model: ClaudeLoginFlowModel

        init(model: ClaudeLoginFlowModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.setStatusMessage(model.strings.claudeLoginOpening)
            model.updateCurrentURL(webView.url)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.updateCurrentURL(webView.url)
            model.inspect(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.updateCurrentURL(webView.url)
            model.setStatusMessage(model.strings.claudeLoginWaiting)
            model.inspect(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            model.errorMessage = error.localizedDescription
            model.setStatusMessage(model.strings.claudeLoginLoadFailed)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            model.errorMessage = error.localizedDescription
            model.setStatusMessage(model.strings.claudeLoginLoadFailed)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            model.updateCurrentURL(webView.url)
            model.inspect(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        }
    }
}

private extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}
