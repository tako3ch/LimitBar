import Charts
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct UsageReportView: View {
    @ObservedObject var historyStore: UsageHistoryStore
    @ObservedObject var settings: SettingsStore
    @State private var period: ReportPeriod = .week

    private var isJapanese: Bool { settings.appLanguage.isJapanese }

    enum ReportPeriod: CaseIterable {
        case week, month

        var label: String {
            switch self {
            case .week: "7日間"
            case .month: "30日間"
            }
        }
        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            }
        }
    }

    private var cutoffDate: Date {
        Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -(period.days - 1), to: Date())!
        )
    }

    private var filteredRecords: [UsageDailyRecord] {
        return historyStore.records.filter { $0.date >= cutoffDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ヘッダー
            HStack {
                Text(isJapanese ? "使用量レポート" : "Usage Report")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LimitBarTheme.strongText)

                Spacer()

                Picker("", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // グラフ
            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    isJapanese ? "データなし" : "No Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(isJapanese
                        ? "まだ使用量が記録されていません。"
                        : "No usage data recorded yet.")
                )
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(filteredRecords) { record in
                        LineMark(
                            x: .value(isJapanese ? "日付" : "Date", record.date, unit: .day),
                            y: .value(isJapanese ? "使用率" : "Usage", record.maxPercent)
                        )
                        .foregroundStyle(by: .value(isJapanese ? "サービス" : "Service", record.service.displayName))
                        .symbol(by: .value(isJapanese ? "サービス" : "Service", record.service.displayName))
                        .interpolationMethod(.catmullRom)
                    }

                    RuleMark(y: .value(isJapanese ? "しきい値" : "Threshold", settings.thresholdPercent))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                        .annotation(position: .trailing) {
                            Text("\(Int(settings.thresholdPercent))%")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                }
                .chartXScale(domain: cutoffDate...Date())
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .chartForegroundStyleScale([
                    "Codex": Color.blue,
                    "Claude Code": Color.orange
                ])
                .frame(height: 200)
            }

            // ハイライトカード
            HStack(spacing: 12) {
                ForEach(ServiceKind.allCases) { service in
                    highlightCard(for: service)
                }
            }

            // エクスポートボタン
            HStack {
                Spacer()
                Button {
                    exportData(as: "csv")
                } label: {
                    Label(isJapanese ? "CSV でエクスポート" : "Export CSV", systemImage: "tablecells")
                }
                .buttonStyle(.bordered)

                Button {
                    exportData(as: "json")
                } label: {
                    Label(isJapanese ? "JSON でエクスポート" : "Export JSON", systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .background(LimitBarTheme.canvasBottom.ignoresSafeArea())
    }

    @ViewBuilder
    private func highlightCard(for service: ServiceKind) -> some View {
        let serviceRecords = filteredRecords.filter { $0.service == service }
        let maxRecord = serviceRecords.max(by: { $0.maxPercent < $1.maxPercent })
        let avgPercent = serviceRecords.isEmpty
            ? 0
            : serviceRecords.map(\.maxPercent).reduce(0, +) / Double(serviceRecords.count)

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ServiceLogoMark(service: service, size: 20)
                    Text(service.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LimitBarTheme.strongText)
                }
                Divider()
                if let maxRecord {
                    LabeledContent(
                        isJapanese ? "最高" : "Peak",
                        value: "\(Int(maxRecord.maxPercent))% (\(maxRecord.date.formatted(.dateTime.month().day())))"
                    )
                } else {
                    LabeledContent(isJapanese ? "最高" : "Peak", value: "—")
                }
                LabeledContent(
                    isJapanese ? "平均" : "Average",
                    value: serviceRecords.isEmpty ? "—" : "\(Int(avgPercent))%"
                )
                LabeledContent(
                    isJapanese ? "記録日数" : "Recorded days",
                    value: "\(serviceRecords.count)\(isJapanese ? "日" : " days")"
                )
            }
            .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private func exportData(as format: String) {
        let panel = NSSavePanel()
        panel.title = isJapanese ? "エクスポート" : "Export"
        panel.nameFieldStringValue = "limitbar_usage.\(format)"
        if format == "csv" {
            panel.allowedContentTypes = [.commaSeparatedText]
        } else {
            panel.allowedContentTypes = [.json]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if format == "csv" {
            let csv = buildCSV()
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try? encoder.encode(historyStore.records)
            try? data?.write(to: url, options: .atomic)
        }
    }

    private func buildCSV() -> String {
        var lines = ["date,service,max_percent"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        for record in historyStore.records.sorted(by: { $0.date < $1.date }) {
            lines.append("\(formatter.string(from: record.date)),\(record.service.rawValue),\(Int(record.maxPercent))")
        }
        return lines.joined(separator: "\n")
    }
}

#Preview("Usage Report") {
    UsageReportView(historyStore: UsageHistoryStore(), settings: PreviewSupport.settings)
}
