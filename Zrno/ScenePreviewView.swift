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
        if let image {
            // Monochrome preview: white highlights stay white, shadows take scheme color.
            // The source image is grayscale from CIPhotoEffectNoir.
            // Using .screen blend: white pixels stay white, black pixels show the background.
            let tint = theme.scheme.previewTint
            let shadowColor = Color(red: tint.r * 0.3, green: tint.g * 0.3, blue: tint.b * 0.3)
            Image(decorative: image, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .blendMode(.screen)
                .background(shadowColor)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        } else {
            Rectangle()
                .fill(theme.primaryColor.opacity(0.03))
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 2))
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
