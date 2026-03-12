import SwiftUI

struct ProgressPill: View {
    let percent: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(width * (percent / 100), 8)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint.opacity(0.9))
                    .frame(width: min(fillWidth, width))
            }
        }
        .frame(height: 7)
    }
}
