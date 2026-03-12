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
            get: { model.settings.menuBarEnabled },
            // set は Scene 更新サイクル中に呼ばれる場合があるため Task で非同期化する
            set: { value in Task { @MainActor in model.settings.menuBarEnabled = value } }
        )) {
            MenuBarDashboardView(settings: model.settings, usageStore: model.usageStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: model.settings, usageStore: model.usageStore)
        }
        .defaultSize(width: 460, height: 420)
    }
}
