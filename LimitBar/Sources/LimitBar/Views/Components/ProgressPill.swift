import SwiftUI

struct ProgressPill: View {
    let percent: Double
    let tint: Color

    private var fillScale: CGFloat {
        let normalized = min(max(percent / 100, 0), 1)
        return max(normalized, 0.08)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.08))
            Capsule()
                .fill(tint.opacity(0.9))
                .scaleEffect(x: fillScale, y: 1, anchor: .leading)
        }
        .frame(height: 7)
    }
}
