import SwiftUI

struct CompensationDialView: View {
    @Environment(\.appTheme) private var theme
    @Binding var compensation: Double

    // ±3 EV in 1/3 stop increments
    private let range: ClosedRange<Double> = -3.0...3.0
    private let step: Double = 1.0 / 3.0
    private let tickSpacing: CGFloat = 28
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private var tickCount: Int {
        Int((range.upperBound - range.lowerBound) / step) + 1
    }

    /// Total width of the tick strip
    private var stripWidth: CGFloat {
        CGFloat(tickCount - 1) * tickSpacing
    }

    // Drag state
    @State private var baseOffset: CGFloat = 0
    @State private var dragDelta: CGFloat = 0
    @State private var isDragging = false
    @State private var lastHapticTick: Int = 0 // tick index that last triggered haptic

    /// Current scroll offset combining base + drag
    private var currentOffset: CGFloat {
        baseOffset + dragDelta
    }

    /// Convert a compensation value to an offset (points from center)
    private func offset(for value: Double) -> CGFloat {
        -CGFloat((value - range.lowerBound) / step) * tickSpacing
    }

    /// Convert an offset to a compensation value, clamped and quantized to 1/3 stops
    private func value(for offset: CGFloat) -> Double {
        let rawTick = -offset / tickSpacing
        let rawValue = range.lowerBound + rawTick * step
        let clamped = min(max(rawValue, range.lowerBound), range.upperBound)
        return (clamped * 3).rounded() / 3
    }

    /// Clamp offset so it can't scroll past the range
    private func clampedOffset(_ raw: CGFloat) -> CGFloat {
        let minOffset = offset(for: range.upperBound) // most negative
        let maxOffset = offset(for: range.lowerBound) // most positive (zero)
        return min(max(raw, minOffset), maxOffset)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Current value label
            Text(formattedCompensation)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(compensation == 0 ? theme.secondaryColor : theme.accentColor)
                .contentTransition(.numericText(value: compensation))
                .animation(.easeInOut(duration: 0.15), value: compensation)
                .accessibilityIdentifier("compensationLabel")

            // Dial
            GeometryReader { geo in
                let centerX = geo.size.width / 2

                ZStack(alignment: .topLeading) {
                    // Invisible touch target covering the full area
                    Color.clear
                        .contentShape(Rectangle())

                    // Tick strip
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            let val = range.lowerBound + Double(i) * step
                            let isWhole = abs(val.rounded() - val) < 0.01
                            let isZero = abs(val) < 0.01

                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(theme.primaryColor.opacity(isWhole ? 0.6 : 0.25))
                                    .frame(width: isZero ? 2 : 1, height: isWhole ? 18 : 10)
                            }
                            .frame(width: tickSpacing, height: 18)
                            .overlay(alignment: .bottom) {
                                if isWhole {
                                    Text(wholeStopLabel(val))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(theme.accentColor)
                                        .offset(y: 14)
                                }
                            }
                        }
                    }
                    .offset(x: currentOffset + centerX - tickSpacing / 2)

                    // Center indicator line (fixed at center, same height as whole-stop ticks)
                    Rectangle()
                        .fill(theme.accentColor)
                        .frame(width: 2, height: 18)
                        .offset(x: centerX - 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { gesture in
                            isDragging = true
                            let raw = baseOffset + gesture.translation.width
                            dragDelta = clampedOffset(raw) - baseOffset
                            let newValue = value(for: clampedOffset(raw))
                            let tick = Int((newValue * 3).rounded())
                            if tick != lastHapticTick {
                                feedbackGenerator.impactOccurred()
                                lastHapticTick = tick
                                compensation = newValue
                            }
                        }
                        .onEnded { gesture in
                            let raw = baseOffset + gesture.translation.width
                            baseOffset = clampedOffset(raw)
                            dragDelta = 0
                            let snapped = value(for: baseOffset)
                            compensation = snapped
                            withAnimation(.easeOut(duration: 0.15)) {
                                baseOffset = offset(for: snapped)
                            }
                            isDragging = false
                        }
                )
            }
            .frame(height: 36)
            .clipped()
        }
        .frame(height: 64)
        .padding(.horizontal, 40)
        .accessibilityIdentifier("compensationDial")
        .onAppear {
            baseOffset = offset(for: compensation)
            lastHapticTick = Int((compensation * 3).rounded())
        }
        .onChange(of: compensation) { _, newValue in
            if !isDragging {
                withAnimation(.easeOut(duration: 0.15)) {
                    baseOffset = offset(for: newValue)
                }
            }
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
