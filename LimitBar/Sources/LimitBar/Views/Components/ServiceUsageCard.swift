import SwiftUI

struct ServiceUsageCard: View {
    let snapshot: UsageSnapshot

    private var timeText: String {
        snapshot.lastUpdated.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(snapshot.service.displayName, systemImage: snapshot.service.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LimitBarTheme.strongText)

                        Text(snapshot.status.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(snapshot.status.tint)
                            .textCase(.lowercase)
                    }

                    Spacer()

                    Text("\(Int(snapshot.clampedPercent))%")
                        .font(.system(size: 28, weight: .thin, design: .rounded))
                        .foregroundStyle(LimitBarTheme.strongText)
                        .contentTransition(.numericText())
                }

                ProgressPill(percent: snapshot.clampedPercent, tint: snapshot.status.tint)

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
