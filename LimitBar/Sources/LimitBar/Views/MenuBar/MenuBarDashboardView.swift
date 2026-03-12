import SwiftUI
import AppKit

struct MenuBarDashboardView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore
    var showReport: () -> Void = {}

    private var strings: AppStrings {
        AppStrings(language: settings.appLanguage)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LimitBarTheme.canvasTop, LimitBarTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings.appTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(LimitBarTheme.strongText)
                        Text(settings.displayMode == .minimal ? strings.minimalMode : strings.usagePulseDescription)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(LimitBarTheme.muted)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            Task { await usageStore.refresh() }
                        } label: {
                            Image(systemName: usageStore.isRefreshing ? "arrow.trianglehead.2.clockwise.rotate.90" : "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.strongText)
                        .rotationEffect(.degrees(usageStore.isRefreshing ? 180 : 0))
                        .animation(.easeInOut(duration: 0.5), value: usageStore.isRefreshing)

                        Button {
                            showReport()
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.strongText)

                        SettingsLink {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.strongText)
                    }
                }

                if usageStore.snapshots.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(strings.connectService)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LimitBarTheme.strongText)
                            Text(strings.connectServiceDescription)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(LimitBarTheme.muted)
                        }
                    }
                } else {
                    ForEach(usageStore.snapshots) { snapshot in
                        ServiceUsageCard(snapshot: snapshot, displayMode: settings.displayMode)
                    }
                }

                if let error = usageStore.lastRefreshError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(LimitBarTheme.danger)
                }

                Divider()

                Button(strings.quitApp) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LimitBarTheme.muted)
            }
            .padding(18)
        }
        .frame(width: 360)
    }
}

#Preview("Menu Bar Dashboard") {
    MenuBarDashboardView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
}
