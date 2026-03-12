import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController {
    private var panel: NSPanel?

    func update(using usageStore: UsageStore, settings: SettingsStore) {
        guard settings.widgetEnabled else {
            panel?.orderOut(nil)
            return
        }

        let panel = panel ?? makePanel()
        panel.contentViewController = NSHostingController(
            rootView: FloatingWidgetView(usageStore: usageStore, settings: settings)
        )

        let size = settings.widgetSize == .small
            ? NSSize(width: 210, height: 84)
            : NSSize(width: 260, height: 96)
        panel.setContentSize(size)
        panel.level = settings.widgetAlwaysOnTop ? .floating : .normal
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel() -> NSPanel {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NSPanel(
            contentRect: NSRect(x: 40, y: 120, width: 210, height: 84),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .normal
        panel.isMovableByWindowBackground = true
        return panel
    }
}
