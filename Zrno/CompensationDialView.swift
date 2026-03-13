import SwiftUI

struct CompensationDialView: View {
    @Environment(\.appTheme) private var theme
    @Binding var compensation: Double

    // ±3 EV in 1/3 stop increments
    private let range: ClosedRange<Double> = -3.0...3.0
    private let step: Double = 1.0 / 3.0
    private let tickSpacing: CGFloat = 18
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    @State private var dragAccumulator: CGFloat = 0
    @State private var lastSnapped: Double = 0

    private var tickCount: Int {
        Int((range.upperBound - range.lowerBound) / step) + 1
    }

    /// Pixel offset for the tick strip so the current compensation is centered.
    private func stripOffset(containerWidth: CGFloat) -> CGFloat {
        let center = containerWidth / 2
        let zeroPosition = CGFloat((0 - range.lowerBound) / step) * tickSpacing
        let compPosition = CGFloat((compensation - range.lowerBound) / step) * tickSpacing
        return center - compPosition + dragAccumulator
    }

    var body: some View {
        VStack(spacing: 8) {
            // Current value
            Text(formattedCompensation)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(compensation == 0 ? theme.secondaryColor : theme.accentColor)
                .contentTransition(.numericText(value: compensation))
                .animation(.easeInOut(duration: 0.15), value: compensation)

            // Dial
            GeometryReader { geo in
                ZStack {
                    // Center indicator
                    Rectangle()
                        .fill(theme.accentColor)
                        .frame(width: 2, height: 28)

                    // Tick strip — positioned via offset, dragged directly
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            let value = range.lowerBound + Double(i) * step
                            let isWhole = abs(value.rounded() - value) < 0.01
                            let isZero = abs(value) < 0.01

                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(theme.primaryColor.opacity(isWhole ? 0.6 : 0.25))
                                    .frame(width: isZero ? 2 : 1, height: isWhole ? 18 : 10)

                                if isWhole {
                                    Text(wholeStopLabel(value))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(theme.primaryColor.opacity(0.35))
                                }
                            }
                            .frame(width: tickSpacing)
                        }
                    }
                    .offset(x: stripOffset(containerWidth: geo.size.width))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            dragAccumulator = value.translation.width
                            let stepsFromDrag = Double(-dragAccumulator) / Double(tickSpacing)
                            let snapped = (round(stepsFromDrag * 3) / 3)
                            let newValue = min(max(lastSnapped + snapped, range.lowerBound), range.upperBound)
                            let quantized = (newValue * 3).rounded() / 3
                            if abs(quantized - compensation) > 0.01 {
                                feedbackGenerator.impactOccurred()
                                compensation = quantized
                            }
                        }
                        .onEnded { _ in
                            lastSnapped = compensation
                            dragAccumulator = 0
                        }
                )
            }
            .frame(height: 36)
            .clipped()
        }
        .frame(height: 60)
        .padding(.horizontal, 40)
        .onAppear {
            lastSnapped = compensation
        }
        .onChange(of: compensation) { _, newValue in
            // Keep lastSnapped in sync for external changes
            lastSnapped = newValue
        }
    }

    private var formattedCompensation: String {
        if abs(compensation) < 0.01 {
            return "±0"
        }
        let sign = compensation > 0 ? "+" : ""
        let thirds = Int((compensation * 3).rounded())
        if thirds % 3 == 0 {
            return "\(sign)\(thirds / 3)"
        }
        return String(format: "%@%.1f", sign, compensation)
    }

    private func wholeStopLabel(_ value: Double) -> String {
        let intVal = Int(value.rounded())
        if intVal == 0 { return "0" }
        if intVal > 0 { return "+\(intVal)" }
        return "\(intVal)"
    }
}
