import Foundation

struct HistoricalSnapshot: Codable {
    let timestamp: Date
    let percent: Double
}

struct UsageDailyRecord: Codable, Identifiable {
    var id: String { "\(service.rawValue)_\(Int(date.timeIntervalSince1970))" }
    let date: Date
    let service: ServiceKind
    var maxPercent: Double
    var snapshots: [HistoricalSnapshot]
}

@MainActor
final class UsageHistoryStore: ObservableObject {
    @Published private(set) var records: [UsageDailyRecord] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LimitBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("usage_history.json")
        load()
    }

    func record(snapshots: [UsageSnapshot]) {
        let today = Calendar.current.startOfDay(for: Date())
        for snapshot in snapshots {
            let hist = HistoricalSnapshot(timestamp: snapshot.lastUpdated, percent: snapshot.clampedPercent)
            if let idx = records.firstIndex(where: {
                Calendar.current.isDate($0.date, inSameDayAs: today) && $0.service == snapshot.service
            }) {
                records[idx].snapshots.append(hist)
                records[idx].maxPercent = max(records[idx].maxPercent, snapshot.clampedPercent)
            } else {
                records.append(UsageDailyRecord(
                    date: today,
                    service: snapshot.service,
                    maxPercent: snapshot.clampedPercent,
                    snapshots: [hist]
                ))
            }
        }
        pruneOldRecords()
        save()
    }

    private func pruneOldRecords() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        records.removeAll { $0.date < cutoff }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([UsageDailyRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
