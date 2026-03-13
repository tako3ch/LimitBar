import SwiftUI

@main
struct LimitBarApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        Task { @MainActor in
            model.start()
        }
    }

    var body: some Scene {
        MenuBarExtra(model.menuBarTitle, systemImage: "gauge.with.needle.fill", isInserted: Binding(
            get: { model.menuBarEnabled },
            set: { value in model.setMenuBarEnabledFromUI(value) }
        )) {
            MenuBarDashboardView(settings: model.settings, usageStore: model.usageStore, showReport: { model.showReportWindow() })
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settings: model.settings,
                usageStore: model.usageStore,
                onCheckForUpdates: { model.checkForUpdates() }
            )
        }
        .defaultSize(width: 540, height: 560)
    }
}
