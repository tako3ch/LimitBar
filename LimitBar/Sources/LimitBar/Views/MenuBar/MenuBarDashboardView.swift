import SwiftUI

struct MenuBarDashboardView: View {
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
                        Text("Usage pulse for Codex and Claude Code")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(LimitBarTheme.muted)
                    }

                    Spacer()

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
                }

                ForEach(usageStore.snapshots) { snapshot in
                    ServiceUsageCard(snapshot: snapshot)
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
    MenuBarDashboardView(usageStore: PreviewSupport.usageStore)
}
