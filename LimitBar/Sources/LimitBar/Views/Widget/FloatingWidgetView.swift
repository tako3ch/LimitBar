import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore

    private var cardPadding: CGFloat {
        settings.widgetSize == .small ? 14 : 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if settings.displayMode == .normal {
                HStack {
                    Text("LimitBar")
                        .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .medium))
                        .foregroundStyle(LimitBarTheme.muted)
                    Spacer()
                    Image(systemName: "capsule.lefthalf.filled")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.accent)
                }
            }

            if usageStore.snapshots.isEmpty {
                Text("Connect Codex or Claude Code in Settings")
                    .font(.system(size: settings.widgetSize == .small ? 11 : 12, weight: .medium))
                    .foregroundStyle(LimitBarTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(usageStore.snapshots) { snapshot in
                    HStack(spacing: 10) {
                        if settings.displayMode == .normal {
                            ServiceLogoMark(service: snapshot.service, size: settings.widgetSize == .small ? 18 : 20)
                        } else {
                            Circle()
                                .fill(snapshot.status.tint)
                                .frame(width: 7, height: 7)
                        }

                        Text(settings.displayMode == .minimal ? snapshot.service.shortLabel : snapshot.service.displayName)
                            .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .semibold))
                            .foregroundStyle(LimitBarTheme.strongText)
                            .frame(width: settings.displayMode == .minimal ? 24 : 84, alignment: .leading)

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
        }
        .padding(cardPadding)
        .frame(width: widgetWidth)
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

    private var widgetWidth: CGFloat {
        if settings.displayMode == .minimal {
            return settings.widgetSize == .small ? 210 : 240
        }
        return settings.widgetSize == .small ? 240 : 290
    }
}

#Preview("Floating Widget") {
    FloatingWidgetView(usageStore: PreviewSupport.usageStore, settings: PreviewSupport.settings)
        .padding()
        .background(Color.black)
}
