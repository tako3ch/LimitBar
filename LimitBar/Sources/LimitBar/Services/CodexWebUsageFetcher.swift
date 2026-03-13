import Foundation
import WebKit

@MainActor
final class CodexWebUsageFetcher: NSObject {
    static let shared = CodexWebUsageFetcher()

    private var activeTasks: [UUID: WebTask] = [:]

    func fetchUsage(using session: LocalAccountSession) async throws -> Data {
        let taskID = UUID()
        let webTask = WebTask(session: session)
        activeTasks[taskID] = webTask
        defer { activeTasks[taskID] = nil }
        return try await webTask.run()
    }

    private final class WebTask: NSObject, WKNavigationDelegate {
        private let session: LocalAccountSession
        private let webView: WKWebView
        private var continuation: CheckedContinuation<Data, Error>?
        private var hasStartedFetch = false

        init(session: LocalAccountSession) {
            self.session = session
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            webView = WKWebView(frame: .zero, configuration: configuration)
            super.init()
            webView.navigationDelegate = self
            webView.customUserAgent = CodexUsageProvider.browserUserAgent
        }

        func run() async throws -> Data {
            try await seedCookies()
            webView.load(URLRequest(url: URL(string: "https://chatgpt.com/")!))

            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                Task { @MainActor [weak self] in
                    try await Task.sleep(for: .seconds(20))
                    guard let self, let continuation = self.continuation else { return }
                    self.continuation = nil
                    continuation.resume(throwing: UsageProviderError.challengeRequired(.codex))
                }
            }
        }

        private func seedCookies() async throws {
            for cookie in session.cookies {
                await webView.configuration.websiteDataStore.httpCookieStore.setCookieAsync(cookie)
            }
        }

        private func startFetchIfNeeded() {
            guard !hasStartedFetch else { return }
            hasStartedFetch = true

            // fetch() は Promise を返すため evaluateJavaScript ではなく callAsyncJavaScript を使う
            let script = """
            const response = await fetch('https://chatgpt.com/backend-api/wham/usage', {
              credentials: 'include',
              headers: { 'accept': 'application/json' }
            });
            const body = await response.text();
            return JSON.stringify({ status: response.status, body });
            """

            webView.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { [weak self] result in
                guard let self, let continuation = self.continuation else { return }
                self.continuation = nil

                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let value):
                    guard
                        let payload = value as? String,
                        let data = payload.data(using: .utf8),
                        let response = try? JSONDecoder().decode(WebFetchResponse.self, from: data)
                    else {
                        continuation.resume(throwing: UsageProviderError.invalidResponse(.codex))
                        return
                    }

                    switch response.status {
                    case 200...299:
                        guard let bodyData = response.body.data(using: .utf8) else {
                            continuation.resume(throwing: UsageProviderError.invalidResponse(.codex))
                            return
                        }
                        continuation.resume(returning: bodyData)
                    case 401, 403:
                        continuation.resume(throwing: UsageProviderError.unauthorized(.codex))
                    default:
                        if response.body.localizedCaseInsensitiveContains("Just a moment") {
                            continuation.resume(throwing: UsageProviderError.challengeRequired(.codex))
                        } else {
                            continuation.resume(throwing: UsageProviderError.invalidResponse(.codex))
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startFetchIfNeeded()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(throwing: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(throwing: error)
        }
    }
}

private struct WebFetchResponse: Decodable {
    let status: Int
    let body: String
}

private extension WKHTTPCookieStore {
    @MainActor
    func setCookieAsync(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            setCookie(cookie) {
                continuation.resume()
            }
        }
    }
}
