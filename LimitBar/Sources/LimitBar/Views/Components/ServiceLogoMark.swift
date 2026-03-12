import SwiftUI

struct ServiceLogoMark: View {
    let service: ServiceKind
    var size: CGFloat = 30

    private var gradient: LinearGradient {
        switch service {
        case .codex:
            LinearGradient(
                colors: [Color(red: 0.43, green: 0.73, blue: 0.92), Color(red: 0.24, green: 0.40, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .claudeCode:
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.66, blue: 0.34), Color(red: 0.82, green: 0.34, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch service {
        case .codex:
            Color(red: 0.22, green: 0.40, blue: 0.88).opacity(0.35)
        case .claudeCode:
            Color(red: 0.74, green: 0.30, blue: 0.24).opacity(0.35)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(gradient)

            Text(service.logoText)
                .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, y: 5)
        .accessibilityLabel(service.displayName)
    }
}

#Preview {
    HStack(spacing: 12) {
        ServiceLogoMark(service: .codex, size: 34)
        ServiceLogoMark(service: .claudeCode, size: 34)
    }
    .padding()
    .background(Color.black)
}
