import AppKit
import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore

    private var strings: AppStrings {
        AppStrings(language: settings.appLanguage)
    }

    private var cardPadding: CGFloat {
        settings.widgetSize == .small ? 14 : 18
    }

    private var cornerRadius: CGFloat {
        settings.widgetSize == .small ? 20 : 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if settings.displayMode == .normal {
                HStack {
                    Text(strings.appTitle)
                        .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .medium))
                        .foregroundStyle(LimitBarTheme.muted)
                    Spacer()
                    Image(systemName: "capsule.lefthalf.filled")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.accent)
                }
            }

            if usageStore.snapshots.isEmpty {
                Text(strings.connectServicesWidget)
                    .font(.system(size: settings.widgetSize == .small ? 11 : 12, weight: .medium))
                    .foregroundStyle(LimitBarTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(usageStore.snapshots) { snapshot in
                    if settings.displayMode == .minimal {
                        minimalRow(for: snapshot)
                    } else {
                        normalRow(for: snapshot)
                    }
                }
            }
        }
        .padding(cardPadding)
        .frame(width: widgetWidth)
        .background(
            widgetBackground
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture(count: 2, perform: openSettings)
    }

    private var widgetWidth: CGFloat {
        if settings.displayMode == .minimal {
            return settings.widgetSize == .small ? 152 : 176
        }
        return settings.widgetSize == .small ? 240 : 290
    }

    @ViewBuilder
    private func normalRow(for snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 10) {
            ServiceLogoMark(service: snapshot.service, size: settings.widgetSize == .small ? 18 : 20)

            Text(snapshot.service.displayName)
                .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .semibold))
                .foregroundStyle(LimitBarTheme.strongText)
                .frame(width: 84, alignment: .leading)

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

    @ViewBuilder
    private func minimalRow(for snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 10) {
            ServiceLogoMark(service: snapshot.service, size: settings.widgetSize == .small ? 18 : 20)

            Spacer(minLength: 0)

            Text("\(Int(snapshot.clampedPercent))%")
                .font(.system(size: settings.widgetSize == .small ? 20 : 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LimitBarTheme.strongText)
                .frame(width: settings.widgetSize == .small ? 58 : 70, alignment: .trailing)
        }
        .frame(height: settings.widgetSize == .small ? 22 : 26)
    }

    private var widgetBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(Color.black.opacity(0.34))

            shape
                .fill(.ultraThinMaterial)

            shape
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.22), radius: 24, y: 8)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

#Preview("Floating Widget") {
    FloatingWidgetView(usageStore: PreviewSupport.usageStore, settings: PreviewSupport.settings)
        .padding()
        .background(Color.black)
}
