import SwiftUI

@main
struct LimitBarApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra(model.menuBarTitle, systemImage: "gauge.with.needle.fill", isInserted: Binding(
            get: { model.settings.menuBarEnabled },
            set: { model.settings.menuBarEnabled = $0 }
        )) {
            MenuBarDashboardView(usageStore: model.usageStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: model.settings, usageStore: model.usageStore)
        }
        .defaultSize(width: 460, height: 420)
    }
}
