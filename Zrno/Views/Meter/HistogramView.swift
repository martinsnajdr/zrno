import SwiftUI

struct HistogramView: View {
    @Environment(\.appTheme) private var theme

    let bins: [Float]

    // Pixel grid: matches preview resolution (36x24, 3:2 aspect)
    private let gridW = 36
    private let gridH = 24

    var body: some View {
        if let img = histogramImage() {
            Image(decorative: img, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(CGFloat(gridW) / CGFloat(gridH), contentMode: .fit)
        }
    }

    private func histogramImage() -> CGImage? {
        // Downsample 256 bins → 36 columns by averaging groups
        let binGroupSize = bins.count / gridW
        var downsampled = [Float](repeating: 0, count: gridW)
        for col in 0..<gridW {
            let start = col * binGroupSize
            let end = min(start + binGroupSize, bins.count)
            var sum: Float = 0
            for i in start..<end { sum += bins[i] }
            downsampled[col] = sum / Float(end - start)
        }

        // Normalize to 0...1
        let peak = downsampled.max() ?? 1
        guard peak > 0 else { return nil }
        for i in 0..<gridW { downsampled[i] /= peak }

        // Resolve colors
        let bgRGB = UIColor(theme.backgroundColor).rgbComponents
        let fgRGB = UIColor(theme.primaryColor).rgbComponents

        // Build pixel buffer
        var pixels = [UInt8](repeating: 0, count: gridW * gridH * 4)
        for col in 0..<gridW {
            let fillHeight = Int(round(downsampled[col] * Float(gridH)))
            for row in 0..<gridH {
                let dstOffset = (row * gridW + col) * 4
                // row 0 = top of image
                let rowFromBottom = gridH - 1 - row
                let filled = rowFromBottom < fillHeight
                // Filled pixels get foreground at partial opacity for gradient feel
                let opacity = filled ? (0.3 + 0.7 * Double(rowFromBottom) / Double(gridH)) : 0.0
                let r = bgRGB.r * (1 - opacity) + fgRGB.r * opacity
                let g = bgRGB.g * (1 - opacity) + fgRGB.g * opacity
                let b = bgRGB.b * (1 - opacity) + fgRGB.b * opacity
                pixels[dstOffset + 0] = UInt8(clamping: Int(r * 255))
                pixels[dstOffset + 1] = UInt8(clamping: Int(g * 255))
                pixels[dstOffset + 2] = UInt8(clamping: Int(b * 255))
                pixels[dstOffset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: gridW, height: gridH,
            bitsPerComponent: 8, bytesPerRow: gridW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return ctx.makeImage()
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
