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
            width = settings.widgetSize == .small ? 210 : 240
        } else {
            width = settings.widgetSize == .small ? 240 : 290
        }
        let rowCount = max(usageStore.snapshots.count, 1)
        let rowHeight = settings.widgetSize == .small ? 18.0 : 22.0
        let topArea = settings.displayMode == .minimal ? 20.0 : 34.0
        let height = topArea + (Double(rowCount) * rowHeight) + Double(settings.widgetSize == .small ? 28 : 34)
        panel.setContentSize(NSSize(width: width, height: height))
        panel.level = settings.widgetAlwaysOnTop ? .floating : .normal
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
        return panel
    }
}
