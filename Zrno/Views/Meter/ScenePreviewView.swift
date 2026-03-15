import SwiftUI
import UIKit

/// Camera preview, histogram, and game – cycled via swipe/tap.
/// During transition, pixels morph from old view to new view in random order.
struct ScenePreviewView: View {
    @Environment(\.appTheme) private var theme

    let image: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode

    // Shared grid dimensions (all views use 36x24, 3:2)
    private let gridW = 36
    private let gridH = 24

    // Transition state
    @State private var isTransitioning = false
    @State private var transitionProgress: Double = 0.0
    @State private var pixelOrder: [Int] = []
    @State private var oldPixels: [UInt8] = []   // RGBA snapshot of the departing view
    @State private var redrawTimer: Timer?
    @State private var hapticTimer: Timer?

    // Games
    @State private var arkanoid = ArkanoidGame()
    @State private var runner = RunnerGame()

    var body: some View {
        ZStack {
            Group {
                if isTransitioning, let composite = buildTransitionImage() {
                    Image(decorative: composite, scale: 1.0)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(3.0 / 2.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else if previewMode == .game || previewMode == .runner {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                        if let img = currentImage() {
                            Image(decorative: img, scale: 1.0)
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(3.0 / 2.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                } else {
                    if let img = currentImage() {
                        Image(decorative: img, scale: 1.0)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(3.0 / 2.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Rectangle()
                            .fill(theme.primaryColor.opacity(0.03))
                            .aspectRatio(3.0 / 2.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.system(size: 16))
                                    .foregroundStyle(theme.primaryColor.opacity(0.15))
                            }
                    }
                }
            }
            .allowsHitTesting(false)

            // UIKit touch layer — fires tap instantly on touchesBegan,
            // immune to TimelineView rebuilds
            GestureOverlay(
                onTap: { handleGameTap() },
                onSwipeLeft: { switchMode(forward: true) },
                onSwipeRight: { switchMode(forward: false) }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .onAppear {
            if previewMode == .game { arkanoid.start() }
            if previewMode == .runner { runner.start() }
        }
        .onChange(of: previewMode) { oldMode, newMode in
            if oldMode == .game { arkanoid.stop() }
            if oldMode == .runner { runner.stop() }
            if newMode == .game { arkanoid.start() }
            if newMode == .runner { runner.start() }
        }
        .accessibilityIdentifier("scenePreview")
    }

    private func handleGameTap() {
        if previewMode == .game {
            arkanoid.handleTap()
        } else if previewMode == .runner {
            runner.handleTap()
        }
    }

    // MARK: - Current Image

    /// Returns the CGImage for the current mode (no transition).
    private func currentImage() -> CGImage? {
        switch previewMode {
        case .histogram:
            return buildHistogramImage()
        case .camera:
            guard let image else { return nil }
            return tintedImage(image)
        case .game:
            return buildGameImage(from: arkanoid)
        case .runner:
            return buildRunnerImage()
        }
    }

    // MARK: - Histogram Image (36x24, 3:2)

    private func buildHistogramImage() -> CGImage? {
        let binGroupSize = max(1, histogramBins.count / gridW)
        var downsampled = [Float](repeating: 0, count: gridW)
        for col in 0..<gridW {
            let start = col * binGroupSize
            let end = min(start + binGroupSize, histogramBins.count)
            guard end > start else { continue }
            var sum: Float = 0
            for i in start..<end { sum += histogramBins[i] }
            downsampled[col] = sum / Float(end - start)
        }

        let peak = downsampled.max() ?? 1
        guard peak > 0 else { return nil }
        for i in 0..<gridW { downsampled[i] /= peak }

        // Colors
        let bgRGB = UIColor(theme.backgroundColor).rgbComponents
        let fgRGB = UIColor(theme.primaryColor).rgbComponents

        var pixels = [UInt8](repeating: 0, count: gridW * gridH * 4)
        for col in 0..<gridW {
            let fillHeight = Int(round(downsampled[col] * Float(gridH)))
            for row in 0..<gridH {
                let offset = (row * gridW + col) * 4
                let rowFromBottom = gridH - 1 - row
                let filled = rowFromBottom < fillHeight
                let opacity = filled ? (0.3 + 0.7 * Double(rowFromBottom) / Double(gridH)) : 0.0
                let r = bgRGB.r * (1 - opacity) + fgRGB.r * opacity
                let g = bgRGB.g * (1 - opacity) + fgRGB.g * opacity
                let b = bgRGB.b * (1 - opacity) + fgRGB.b * opacity
                pixels[offset + 0] = UInt8(clamping: Int(r * 255))
                pixels[offset + 1] = UInt8(clamping: Int(g * 255))
                pixels[offset + 2] = UInt8(clamping: Int(b * 255))
                pixels[offset + 3] = 255
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

    // MARK: - Game Images (36x24, 3:2)

    /// Resolves game background color (slightly shifted from theme bg)
    private func gameColors() -> (fg: (r: UInt8, g: UInt8, b: UInt8), bg: (r: UInt8, g: UInt8, b: UInt8)) {
        let fgRGB = UIColor(theme.primaryColor).rgbComponents
        let bgRGB = UIColor(theme.backgroundColor).rgbComponents
        let mix = 0.08
        let gameBgR = bgRGB.r * (1 - mix) + fgRGB.r * mix
        let gameBgG = bgRGB.g * (1 - mix) + fgRGB.g * mix
        let gameBgB = bgRGB.b * (1 - mix) + fgRGB.b * mix
        return (
            fg: (UInt8(clamping: Int(fgRGB.r * 255)), UInt8(clamping: Int(fgRGB.g * 255)), UInt8(clamping: Int(fgRGB.b * 255))),
            bg: (UInt8(clamping: Int(gameBgR * 255)), UInt8(clamping: Int(gameBgG * 255)), UInt8(clamping: Int(gameBgB * 255)))
        )
    }

    private func buildGameImage(from gameState: ArkanoidGame) -> CGImage? {
        let colors = gameColors()
        var pixels = gameState.render(
            fgR: colors.fg.r, fgG: colors.fg.g, fgB: colors.fg.b,
            bgR: colors.bg.r, bgG: colors.bg.g, bgB: colors.bg.b
        )

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

    private func buildRunnerImage() -> CGImage? {
        let colors = gameColors()
        var pixels = runner.render(
            fgR: colors.fg.r, fgG: colors.fg.g, fgB: colors.fg.b,
            bgR: colors.bg.r, bgG: colors.bg.g, bgB: colors.bg.b
        )

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

    // MARK: - Transition Composite

    /// Builds a 36x24 image that shows old pixels for not-yet-revealed positions
    /// and new (current mode) pixels for revealed positions.
    private func buildTransitionImage() -> CGImage? {
        let totalPixels = gridW * gridH
        let revealedCount = Int(transitionProgress * Double(totalPixels))

        // Get current (new) mode's pixels
        guard let newImage = currentImage(),
              let newData = newImage.dataProvider?.data,
              let newPtr = CFDataGetBytePtr(newData) else {
            return nil
        }
        let newBpp = newImage.bitsPerPixel / 8

        // Start with old pixels
        var pixels = oldPixels
        guard pixels.count == totalPixels * 4 else { return nil }

        // Replace revealed positions with new image pixels
        let safeCount = min(revealedCount, pixelOrder.count)
        for j in 0..<safeCount {
            let idx = pixelOrder[j]
            guard idx < totalPixels else { continue }
            let row = idx / gridW
            let col = idx % gridW
            let srcOffset = row * newImage.bytesPerRow + col * newBpp
            let dstOffset = idx * 4
            pixels[dstOffset + 0] = newPtr[srcOffset + 0]
            pixels[dstOffset + 1] = newPtr[srcOffset + 1]
            pixels[dstOffset + 2] = newPtr[srcOffset + 2]
            pixels[dstOffset + 3] = 255
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

    // MARK: - Snapshot

    /// Captures current mode's image as an RGBA pixel array.
    private func snapshotCurrentPixels() -> [UInt8] {
        let totalPixels = gridW * gridH
        var result = [UInt8](repeating: 0, count: totalPixels * 4)

        // Fill with background color as fallback
        let bgRGB = UIColor(theme.backgroundColor).rgbComponents
        for i in 0..<totalPixels {
            let offset = i * 4
            result[offset + 0] = UInt8(clamping: Int(bgRGB.r * 255))
            result[offset + 1] = UInt8(clamping: Int(bgRGB.g * 255))
            result[offset + 2] = UInt8(clamping: Int(bgRGB.b * 255))
            result[offset + 3] = 255
        }

        guard let img = currentImage(),
              let data = img.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return result
        }
        let bpp = img.bitsPerPixel / 8
        for row in 0..<gridH {
            for col in 0..<gridW {
                let srcOffset = row * img.bytesPerRow + col * bpp
                let dstOffset = (row * gridW + col) * 4
                result[dstOffset + 0] = ptr[srcOffset + 0]
                result[dstOffset + 1] = ptr[srcOffset + 1]
                result[dstOffset + 2] = ptr[srcOffset + 2]
                result[dstOffset + 3] = 255
            }
        }
        return result
    }

    // MARK: - Mode Switching

    private func switchMode(forward: Bool) {
        guard !isTransitioning else { return }

        // Snapshot old view's pixels before switching
        oldPixels = snapshotCurrentPixels()

        // Switch mode
        previewMode = forward ? previewMode.next : previewMode.previous

        // Prepare random reveal order
        let totalPixels = gridW * gridH
        pixelOrder = Array(0..<totalPixels).shuffled()
        transitionProgress = 0.0
        isTransitioning = true

        // Animation timing
        let duration: Double = 1.0
        let steps = 30
        let interval = duration / Double(steps)
        let increment = 1.0 / Double(steps)

        // Haptic feedback
        let hapticGen = UIImpactFeedbackGenerator(style: .light)
        hapticGen.prepare()
        hapticGen.impactOccurred()

        // Progress timer
        redrawTimer?.invalidate()
        redrawTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            transitionProgress += increment
            if transitionProgress >= 1.0 {
                transitionProgress = 1.0
                timer.invalidate()
                redrawTimer = nil
                isTransitioning = false
            }
        }

        // Haptic timer – multiple taps during the animation
        hapticTimer?.invalidate()
        let hapticInterval = duration / 8.0
        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) { timer in
            if !isTransitioning {
                timer.invalidate()
                hapticTimer = nil
            } else {
                hapticGen.impactOccurred(intensity: 0.4)
            }
        }
    }

    /// Remap grayscale CGImage pixels to theme colors, returning a new CGImage.
    /// Shadow color for dark pixels, highlight color for bright pixels.
    private func tintedImage(_ source: CGImage) -> CGImage? {
        let w = source.width
        let h = source.height

        // Resolve theme colors to RGB components
        // In dark mode: dark pixels → dark bg, bright pixels → light primary (natural)
        // In light mode: dark pixels → dark primary, bright pixels → light bg (natural)
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

// MARK: - UIKit Gesture Overlay

/// UIKit view that fires tap on touchesBegan (instant) and detects swipes on touchesEnded.
/// Lives as a stable UIView layer unaffected by TimelineView rebuilds.
private struct GestureOverlay: UIViewRepresentable {
    let onTap: () -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeUIView(context: Context) -> GestureView {
        let view = GestureView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = false
        view.onTap = onTap
        view.onSwipeLeft = onSwipeLeft
        view.onSwipeRight = onSwipeRight
        return view
    }

    func updateUIView(_ uiView: GestureView, context: Context) {
        uiView.onTap = onTap
        uiView.onSwipeLeft = onSwipeLeft
        uiView.onSwipeRight = onSwipeRight
    }

    class GestureView: UIView {
        var onTap: (() -> Void)?
        var onSwipeLeft: (() -> Void)?
        var onSwipeRight: (() -> Void)?
        private var touchStart: CGPoint = .zero

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            if let touch = touches.first {
                touchStart = touch.location(in: self)
            }
            // Fire tap immediately on touch down
            onTap?()
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            guard let touch = touches.first else { return }
            let end = touch.location(in: self)
            let dx = end.x - touchStart.x
            if dx < -40 {
                onSwipeLeft?()
            } else if dx > 40 {
                onSwipeRight?()
            }
        }
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
