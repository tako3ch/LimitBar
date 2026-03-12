import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore

    private var cardPadding: CGFloat {
        settings.widgetSize == .small ? 14 : 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LimitBar")
                    .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .medium))
                    .foregroundStyle(LimitBarTheme.muted)
                Spacer()
                Image(systemName: "capsule.lefthalf.filled")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LimitBarTheme.accent)
            }

            ForEach(usageStore.snapshots) { snapshot in
                HStack(spacing: 10) {
                    Circle()
                        .fill(snapshot.status.tint)
                        .frame(width: 7, height: 7)

                    Text(snapshot.service.shortLabel)
                        .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.strongText)

                    ProgressPill(percent: snapshot.clampedPercent, tint: snapshot.status.tint)
                        .frame(height: 6)

                    Text("\(Int(snapshot.clampedPercent))%")
                        .font(.system(size: settings.widgetSize == .small ? 14 : 16, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LimitBarTheme.strongText)
                        .frame(width: 42, alignment: .trailing)
                }
                .frame(height: settings.widgetSize == .small ? 18 : 22)
            }
        }
        .padding(cardPadding)
        .frame(width: settings.widgetSize == .small ? 210 : 260)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.48))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 24, y: 8)
        )
    }
}

#Preview("Floating Widget") {
    FloatingWidgetView(usageStore: PreviewSupport.usageStore, settings: PreviewSupport.settings)
        .padding()
        .background(Color.black)
}
