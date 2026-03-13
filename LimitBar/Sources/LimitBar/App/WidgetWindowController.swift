import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController {
    private var panel: NSPanel?
    private var lastAppliedSize: NSSize?
    private var lastAppliedPosition: WidgetPosition?
    private var lastAppliedLevel: NSWindow.Level?

    func update(using usageStore: UsageStore, settings: SettingsStore) {
        guard settings.widgetEnabled else {
            panel?.orderOut(nil)
            return
        }

        let layout = WidgetLayout(
            displayMode: settings.displayMode,
            widgetSize: settings.widgetSize
        )

        // パネルが未生成の場合のみ NSHostingController を作成する。
        // FloatingWidgetView は @ObservedObject で usageStore / settings を監視するため、
        // 同一インスタンスを渡し続ければ一度の生成で自動更新される。
        if panel == nil {
            panel = makePanel(usageStore: usageStore, settings: settings)
        }
        let panel = panel!

        let rowCount = displayedRowCount(for: usageStore, settings: settings)
        let newSize = NSSize(width: layout.width, height: layout.height(forRowCount: rowCount))
        let newLevel: NSWindow.Level = settings.widgetAlwaysOnTop ? .floating : .normal
        let shouldApplySize = lastAppliedSize != newSize
        let shouldApplyLevel = lastAppliedLevel != newLevel
        let shouldApplyPosition = lastAppliedPosition != settings.widgetPosition || shouldApplySize
        let shouldShowPanel = !panel.isVisible

        guard shouldApplySize || shouldApplyLevel || shouldApplyPosition || shouldShowPanel else {
            return
        }

        // setContentSize は AppKit の同期レイアウトを引き起こすため、
        // SwiftUI のレンダリングパスとの競合を避けるために非同期で実行する。
        DispatchQueue.main.async {
            if shouldApplySize {
                panel.setContentSize(newSize)
                self.lastAppliedSize = newSize
            }
            if shouldApplyLevel {
                panel.level = newLevel
                self.lastAppliedLevel = newLevel
            }
            if shouldApplyPosition {
                self.updatePanelOrigin(for: panel, position: settings.widgetPosition)
                self.lastAppliedPosition = settings.widgetPosition
            }
            if shouldShowPanel {
                panel.orderFrontRegardless()
            }
        }
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
        lastAppliedSize = panel.frame.size
        lastAppliedPosition = settings.widgetPosition
        lastAppliedLevel = panel.level
        updatePanelOrigin(for: panel, position: settings.widgetPosition)
        return panel
    }

    private func displayedRowCount(for usageStore: UsageStore, settings: SettingsStore) -> Int {
        usageStore.snapshots.reduce(0) { count, snapshot in
            let showsWeekly = settings.showsWeeklyLimitInWidget(for: snapshot.service) && snapshot.clampedWeeklyPercent != nil
            return count + 1 + (showsWeekly ? 1 : 0)
        }
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
