import SwiftUI

/// Camera preview and histogram, cycled via swipe/tap.
/// Always occupies a fixed frame so it doesn't push other controls.
struct ScenePreviewView: View {
    @Environment(\.appTheme) private var theme

    let image: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            switch previewMode {
            case .histogram:
                HistogramView(bins: histogramBins)
                    .frame(maxWidth: .infinity)

            case .camera:
                cameraContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .offset(x: dragOffset)
        .gesture(swipeGesture)
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) {
                previewMode = previewMode.next
            }
        }
        .animation(.spring(duration: 0.3), value: previewMode)
        .animation(.spring(duration: 0.2), value: dragOffset)
        .accessibilityIdentifier("scenePreview")
    }

    // MARK: - Camera Content

    @ViewBuilder
    private var cameraContent: some View {
        if let image, let tinted = tintedImage(image) {
            Image(decorative: tinted, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Rectangle()
                .fill(theme.primaryColor.opacity(0.03))
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay {
                    Image(systemName: "camera")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.primaryColor.opacity(0.15))
                }
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                dragOffset = value.translation.width * 0.3
            }
            .onEnded { value in
                dragOffset = 0
                let threshold: CGFloat = 25
                if value.translation.width < -threshold {
                    withAnimation(.spring(duration: 0.3)) {
                        previewMode = previewMode.next
                    }
                } else if value.translation.width > threshold {
                    withAnimation(.spring(duration: 0.3)) {
                        previewMode = previewMode.previous
                    }
                }
            }
    }

    /// Remap grayscale CGImage pixels to theme colors, returning a new CGImage.
    /// Shadow color for dark pixels, highlight color for bright pixels.
    private func tintedImage(_ source: CGImage) -> CGImage? {
        let w = source.width
        let h = source.height

        // Resolve theme colors to RGB components
        let shadowColor = theme.effectiveIsDark ? theme.backgroundColor : theme.primaryColor
        let highlightColor = theme.effectiveIsDark ? theme.primaryColor : theme.backgroundColor
        let shadowRGB = UIColor(shadowColor).rgbComponents
        let highlightRGB = UIColor(highlightColor).rgbComponents

        // Read source pixels
        guard let srcData = source.dataProvider?.data,
              let srcPtr = CFDataGetBytePtr(srcData) else { return nil }
        let srcBpp = source.bitsPerPixel / 8

        // Create output buffer (RGBA, 8-bit)
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let srcOffset = y * source.bytesPerRow + x * srcBpp
                let lum = Double(srcPtr[srcOffset + 1]) / 255.0 // green channel
                let dstOffset = (y * w + x) * 4
                pixels[dstOffset + 0] = UInt8(clamping: Int((shadowRGB.r * (1 - lum) + highlightRGB.r * lum) * 255))
                pixels[dstOffset + 1] = UInt8(clamping: Int((shadowRGB.g * (1 - lum) + highlightRGB.g * lum) * 255))
                pixels[dstOffset + 2] = UInt8(clamping: Int((shadowRGB.b * (1 - lum) + highlightRGB.b * lum) * 255))
                pixels[dstOffset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return ctx.makeImage()
    }
}

extension UIColor {
    var rgbComponents: (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScenePreviewView(
            image: nil,
            histogramBins: (0..<256).map { i in
                let center: Float = 128
                let spread: Float = 45
                let dist = Float(i) - center
                return exp(-(dist * dist) / (2 * spread * spread))
            },
            previewMode: .constant(.histogram)
        )
    }
}
