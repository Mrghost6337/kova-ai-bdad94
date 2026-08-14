// 10x primitive: cal-ai/design-tokens v1
import SwiftUI

/// KOVA's central monochrome theme. Product surfaces are pure grayscale; views
/// must use these roles instead of introducing colors, typography, or geometry.
enum KOVATokens {
    static let background = Color.black
    static let surface = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let surfaceRaised = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let border = Color(red: 0.149, green: 0.149, blue: 0.149)
    static let text = Color.white
    static let secondaryText = Color(red: 0.631, green: 0.631, blue: 0.631)
    static let tertiaryText = Color(red: 0.420, green: 0.420, blue: 0.420)
    static let accent = Color.white
    static let onAccent = Color.black
    static let progressTrack = Color(red: 0.180, green: 0.180, blue: 0.180)

    static let screenMargin: CGFloat = 20
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 48
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 28
    static let buttonHeight: CGFloat = 56
    static let iconTarget: CGFloat = 44
    static let heroNumberSize: CGFloat = 52
    static let metricNumberSize: CGFloat = 28
    static let ringLineWidth: CGFloat = 10

    static let displayFont = Font.system(size: heroNumberSize, weight: .bold, design: .default).monospacedDigit()
    static let titleFont = Font.system(.title2, design: .default, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default, weight: .regular)
    static let captionFont = Font.system(.footnote, design: .default, weight: .regular)
    static let eyebrowFont = Font.system(.caption, design: .default, weight: .semibold)
}

struct KOVAPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KOVATokens.headlineFont)
            .foregroundStyle(KOVATokens.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: KOVATokens.buttonHeight)
            .background(KOVATokens.accent, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: KOVATokens.md) {
        Text("KOVA")
            .font(KOVATokens.displayFont)
            .foregroundStyle(KOVATokens.text)
        Button("Start session") {}
            .buttonStyle(KOVAPrimaryButtonStyle())
    }
    .padding(KOVATokens.screenMargin)
    .background(KOVATokens.background)
    .preferredColorScheme(.dark)
}
