import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore

    var body: some View {
        Form {
            Section("Monitoring") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notification threshold")
                        Spacer()
                        Text("\(Int(settings.thresholdPercent))%")
                            .foregroundStyle(LimitBarTheme.muted)
                    }
                    Slider(value: $settings.thresholdPercent, in: 50...100, step: 1)
                }

                Picker("Auto refresh", selection: $settings.refreshInterval) {
                    Text("1 min").tag(TimeInterval(60))
                    Text("5 min").tag(TimeInterval(300))
                    Text("10 min").tag(TimeInterval(600))
                    Text("15 min").tag(TimeInterval(900))
                }
                .onChange(of: settings.refreshInterval) { _, _ in
                    usageStore.rescheduleTimer()
                }

                Toggle("Notifications", isOn: $settings.notificationsEnabled)
            }

            Section("Visibility") {
                Toggle("Menu bar item", isOn: $settings.menuBarEnabled)
                Toggle("Floating widget", isOn: $settings.widgetEnabled)
                Toggle("Always on top", isOn: $settings.widgetAlwaysOnTop)
                    .disabled(!settings.widgetEnabled)

                Picker("Widget size", selection: $settings.widgetSize) {
                    Text("S").tag(WidgetSize.small)
                    Text("M").tag(WidgetSize.medium)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Button("Refresh now") {
                    Task { await usageStore.refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}

#Preview("Settings") {
    SettingsView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
}
