import AppKit
import SwiftUI

struct WindowLevelReader: NSViewRepresentable {
    let level: NSWindow.Level

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyLevelIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyLevelIfNeeded(from: nsView)
        }
    }

    private func applyLevelIfNeeded(from view: NSView) {
        guard let window = view.window else { return }
        var needsUpdate = false

        if window.level != level {
            window.level = level
            needsUpdate = true
        }

        if !window.collectionBehavior.contains(.fullScreenAuxiliary) {
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            needsUpdate = true
        }

        // Avoid forcing the settings window to the front on every SwiftUI update.
        // Repeated reactivation causes AppKit layout churn and can pin a CPU core.
        guard needsUpdate else { return }
    }
}
