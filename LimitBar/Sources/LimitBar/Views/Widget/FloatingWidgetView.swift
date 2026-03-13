import AppKit
import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore

    private struct WidgetUsageRow: Identifiable {
        let id: String
        let service: ServiceKind
        let title: String
        let percent: Double
        let status: UsageStatus
        let isWeekly: Bool

        var barTint: Color {
            isWeekly ? service.weeklyColor : LimitBarTheme.progressColor(for: percent, service: service)
        }

        var percentageTint: Color {
            isWeekly ? LimitBarTheme.weeklyText : LimitBarTheme.severityColor(for: percent)
        }
    }

    private var strings: AppStrings {
        AppStrings(language: settings.appLanguage)
    }

    private var layout: WidgetLayout {
        WidgetLayout(
            displayMode: settings.displayMode,
            widgetSize: settings.widgetSize
        )
    }

    private var rowFontSize: CGFloat {
        settings.widgetSize == .small ? 12 : 13
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if settings.displayMode == .normal {
                HStack {
                    Text(strings.appTitle)
                        .font(.system(size: rowFontSize, weight: .medium))
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
                ForEach(widgetRows) { snapshot in
                    if settings.displayMode == .minimal {
                        minimalRow(for: snapshot)
                    } else {
                        normalRow(for: snapshot)
                    }
                }
            }
        }
        .padding(layout.cardPadding)
        .frame(width: layout.width)
        .background(
            widgetBackground
        )
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        .onTapGesture(count: 2, perform: openSettings)
    }

    private var widgetRows: [WidgetUsageRow] {
        orderedSnapshots.flatMap { snapshot in
            var rows = [
                WidgetUsageRow(
                    id: "\(snapshot.service.rawValue)-primary",
                    service: snapshot.service,
                    title: snapshot.service.displayName,
                    percent: snapshot.clampedPercent,
                    status: snapshot.status,
                    isWeekly: false
                )
            ]

            if settings.showsWeeklyLimitInWidget(for: snapshot.service),
               let weeklyPercent = snapshot.clampedWeeklyPercent {
                rows.append(
                    WidgetUsageRow(
                        id: "\(snapshot.service.rawValue)-weekly",
                        service: snapshot.service,
                        title: strings.weeklyLabel,
                        percent: weeklyPercent,
                        status: UsageSnapshot.status(for: weeklyPercent),
                        isWeekly: true
                    )
                )
            }

            return rows
        }
    }

    private var orderedSnapshots: [UsageSnapshot] {
        usageStore.snapshots.sorted { a, b in
            let ia = settings.widgetServiceOrder.firstIndex(of: a.service.rawValue) ?? Int.max
            let ib = settings.widgetServiceOrder.firstIndex(of: b.service.rawValue) ?? Int.max
            return ia < ib
        }
    }

    @ViewBuilder
    private func normalRow(for snapshot: WidgetUsageRow) -> some View {
        HStack(spacing: 10) {
            ServiceLogoMark(service: snapshot.service, size: settings.widgetSize == .small ? 18 : 20)

            Text(snapshot.title)
                .font(.system(size: rowFontSize, weight: .semibold))
                .foregroundStyle(LimitBarTheme.strongText)
                .frame(width: 84, alignment: .leading)

            ProgressPill(percent: snapshot.percent, tint: snapshot.barTint)
                .frame(height: 6)

            Text("\(Int(snapshot.percent))%")
                .font(.system(size: settings.widgetSize == .small ? 14 : 16, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snapshot.percentageTint)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: settings.widgetSize == .small ? 18 : 22)
    }

    @ViewBuilder
    private func minimalRow(for snapshot: WidgetUsageRow) -> some View {
        HStack(spacing: 10) {
            ServiceLogoMark(service: snapshot.service, size: settings.widgetSize == .small ? 18 : 20)

            Spacer(minLength: 0)

            if snapshot.isWeekly {
                Text(strings.weeklyShortLabel)
                    .font(.system(size: settings.widgetSize == .small ? 10 : 11, weight: .semibold))
                    .foregroundStyle(LimitBarTheme.muted)
            }

            Text("\(Int(snapshot.percent))%")
                .font(.system(size: settings.widgetSize == .small ? 20 : 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snapshot.percentageTint)
                .frame(width: settings.widgetSize == .small ? 58 : 70, alignment: .trailing)
        }
        .frame(height: settings.widgetSize == .small ? 22 : 26)
    }

    private var widgetBackground: some View {
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(Color.black.opacity(0.34))

            shape
                .fill(.ultraThinMaterial)

            shape
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .compositingGroup()
        .opacity(settings.widgetOpacity)
        .shadow(color: .black.opacity(0.22 * settings.widgetOpacity), radius: 24, y: 8)
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
