import SwiftUI

struct MenuBarDashboardView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore

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
                        Text("LimitBar")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(LimitBarTheme.strongText)
                        Text(settings.displayMode == .minimal ? "Minimal mode" : "Usage pulse for Codex and Claude Code")
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
                            Text("Connect a service")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LimitBarTheme.strongText)
                            Text("Open Settings to link your Codex or Claude Code account.")
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
            }
            .padding(18)
        }
        .frame(width: 360)
    }
}

#Preview("Menu Bar Dashboard") {
    MenuBarDashboardView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
}
