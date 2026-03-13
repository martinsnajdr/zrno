import SwiftUI

struct HistogramView: View {
    @Environment(\.appTheme) private var theme

    let bins: [Float]

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(bins.count)
            let maxHeight = size.height

            // Fill under the curve
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))

            for (i, value) in bins.enumerated() {
                let x = CGFloat(i) * barWidth
                let h = CGFloat(value) * maxHeight
                path.addLine(to: CGPoint(x: x, y: size.height - h))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()

            context.fill(path, with: .linearGradient(
                Gradient(colors: [
                    theme.accentColor.opacity(0.35),
                    theme.accentColor.opacity(0.1)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Stroke the top edge
            var strokePath = Path()
            for (i, value) in bins.enumerated() {
                let x = CGFloat(i) * barWidth
                let h = CGFloat(value) * maxHeight
                let point = CGPoint(x: x, y: size.height - h)
                if i == 0 {
                    strokePath.move(to: point)
                } else {
                    strokePath.addLine(to: point)
                }
            }
            context.stroke(strokePath, with: .color(theme.accentColor.opacity(0.6)), lineWidth: 1)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HistogramView(bins: {
            // Generate a sample bell curve
            (0..<256).map { i in
                let center: Float = 128
                let spread: Float = 45
                let dist = Float(i) - center
                return exp(-(dist * dist) / (2 * spread * spread))
            }
        }())
        .frame(height: 80)
        .padding(.horizontal, 30)
    }
    .preferredColorScheme(.dark)
}
