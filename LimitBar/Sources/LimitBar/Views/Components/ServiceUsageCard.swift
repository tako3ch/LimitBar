import SwiftUI

struct ServiceUsageCard: View {
    let snapshot: UsageSnapshot
    let displayMode: DisplayMode

    private var timeText: String {
        snapshot.lastUpdated.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: displayMode == .minimal ? 10 : 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ServiceLogoMark(service: snapshot.service, size: displayMode == .minimal ? 28 : 32)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(snapshot.service.displayName)
                                .font(.system(size: displayMode == .minimal ? 13 : 14, weight: .semibold))
                                .foregroundStyle(LimitBarTheme.strongText)

                            if displayMode == .normal {
                                Text(snapshot.status.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(snapshot.status.tint)
                                    .textCase(.lowercase)
                            }
                        }
                    }

                    Spacer()

                    Text("\(Int(snapshot.clampedPercent))%")
                        .font(.system(size: displayMode == .minimal ? 24 : 28, weight: .thin, design: .rounded))
                        .foregroundStyle(LimitBarTheme.strongText)
                        .contentTransition(.numericText())
                }

                ProgressPill(percent: snapshot.clampedPercent, tint: snapshot.status.tint)

                if displayMode == .normal {
                    HStack {
                        Text("Updated \(timeText)")
                            .foregroundStyle(LimitBarTheme.muted)
                        Spacer()
                        if let details = snapshot.details {
                            Text(details)
                                .foregroundStyle(LimitBarTheme.muted)
                        }
                    }
                    .font(.system(size: 11, weight: .regular))
                }
            }
        }
    }
}
