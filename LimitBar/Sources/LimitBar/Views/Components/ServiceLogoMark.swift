import AppKit
import SwiftUI

struct ServiceLogoMark: View {
    let service: ServiceKind
    var size: CGFloat = 30

    private var imageName: String {
        switch service {
        case .codex: "openai"
        case .claudeCode: "claude"
        }
    }

    private var accentColor: Color {
        switch service {
        case .codex: Color(red: 0.43, green: 0.73, blue: 0.92)
        case .claudeCode: Color(red: 0.92, green: 0.66, blue: 0.34)
        }
    }

    private var fallbackMonogram: String {
        service.logoText
    }

    private var logoImage: NSImage? {
        guard let url = Bundle.moduleResources.url(forResource: imageName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(accentColor.opacity(0.14))

            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .opacity(0.96)
            } else {
                Text(fallbackMonogram)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor.opacity(0.95))
            }

            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(0.22), radius: 12, y: 5)
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
