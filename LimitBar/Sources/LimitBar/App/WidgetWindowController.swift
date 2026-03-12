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

        // パネルが未生成の場合のみ NSHostingController を作成する。
        // FloatingWidgetView は @ObservedObject で usageStore / settings を監視するため、
        // 同一インスタンスを渡し続ければ一度の生成で自動更新される。
        if panel == nil {
            panel = makePanel(usageStore: usageStore, settings: settings)
        }
        let panel = panel!

        let width: CGFloat
        if settings.displayMode == .minimal {
            width = settings.widgetSize == .small ? 152 : 176
        } else {
            width = settings.widgetSize == .small ? 240 : 290
        }
        let rowCount = max(usageStore.snapshots.count, 1)
        let rowHeight = settings.displayMode == .minimal
            ? (settings.widgetSize == .small ? 22.0 : 26.0)
            : (settings.widgetSize == .small ? 18.0 : 22.0)
        let topArea = settings.displayMode == .minimal ? 0.0 : 34.0
        let verticalPadding = settings.widgetSize == .small ? 28.0 : 36.0
        let height = topArea + (Double(rowCount) * rowHeight) + verticalPadding
        panel.setContentSize(NSSize(width: width, height: height))
        panel.level = settings.widgetAlwaysOnTop ? .floating : .normal
        updatePanelOrigin(for: panel, position: settings.widgetPosition)
        panel.orderFrontRegardless()
    }

    private func makePanel(usageStore: UsageStore, settings: SettingsStore) -> NSPanel {
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
        panel.contentViewController = NSHostingController(
            rootView: FloatingWidgetView(usageStore: usageStore, settings: settings)
        )
        updatePanelOrigin(for: panel, position: settings.widgetPosition)
        return panel
    }

    private func updatePanelOrigin(for panel: NSPanel, position: WidgetPosition) {
        guard let screen = targetScreen(for: panel) else { return }

        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 20
        let size = panel.frame.size

        let origin = CGPoint(
            x: position == .topRight || position == .bottomRight
                ? visibleFrame.maxX - size.width - margin
                : visibleFrame.minX + margin,
            y: position == .topLeft || position == .topRight
                ? visibleFrame.maxY - size.height - margin
                : visibleFrame.minY + margin
        )

        panel.setFrameOrigin(origin)
    }

    private func targetScreen(for panel: NSPanel) -> NSScreen? {
        let panelFrame = panel.frame

        if let matchingScreen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panelFrame) }) {
            return matchingScreen
        }

        return panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
}
