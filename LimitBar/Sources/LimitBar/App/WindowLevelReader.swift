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
        guard window.level != level else { return }

        window.level = level
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}
