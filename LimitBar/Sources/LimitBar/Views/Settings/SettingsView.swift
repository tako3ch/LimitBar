import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore

    var body: some View {
        Form {
            Section("Accounts") {
                VStack(spacing: 12) {
                    ForEach(ServiceKind.allCases) { service in
                        AccountIntegrationRow(
                            service: service,
                            isConnected: settings.isConnected(service),
                            action: { toggleConnection(for: service) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Appearance") {
                Picker("Display mode", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayMode == .minimal ? "Compact labels and lighter cards for a quieter dashboard." : "Shows logos, status text, and full account context.")
                    .font(.footnote)
                    .foregroundStyle(LimitBarTheme.muted)
            }

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

                Toggle("Notifications", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.setNotificationsEnabled($0) }
                ))
                    .disabled(!AppEnvironment.supportsUserNotifications)
                if !AppEnvironment.supportsUserNotifications {
                    Text("Notifications are available when the app is run from a bundled .app.")
                        .font(.footnote)
                        .foregroundStyle(LimitBarTheme.muted)
                }
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
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                    .disabled(!AppEnvironment.supportsLaunchAtLogin)
                if !AppEnvironment.supportsLaunchAtLogin {
                    Text("Launch at login is available when the app is run from a bundled .app.")
                        .font(.footnote)
                        .foregroundStyle(LimitBarTheme.muted)
                }
                Button("Refresh now") {
                    Task { await usageStore.refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }

    private func toggleConnection(for service: ServiceKind) {
        settings.setConnection(service, isConnected: !settings.isConnected(service))
        Task { await usageStore.refresh() }
    }
}

#Preview("Settings") {
    SettingsView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
}

private struct AccountIntegrationRow: View {
    let service: ServiceKind
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ServiceLogoMark(service: service, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(service.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(isConnected ? "Connected" : "Not connected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isConnected ? LimitBarTheme.success : LimitBarTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill((isConnected ? LimitBarTheme.success : LimitBarTheme.warning).opacity(0.14))
                        )
                }

                Text(isConnected ? service.accountLabel : "Link your \(service.displayName) account to start monitoring usage.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(LimitBarTheme.muted)
            }

            Spacer()

            Button(isConnected ? "Disconnect" : "Connect") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .tint(isConnected ? LimitBarTheme.warning : LimitBarTheme.accent)
        }
        .padding(.vertical, 4)
    }
}
