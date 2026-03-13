import SwiftUI

/// A small floating window that cycles between hidden / camera preview / histogram via swipe.
struct ScenePreviewView: View {
    @Environment(\.appTheme) private var theme

    let image: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode

    private let windowWidth: CGFloat = 140
    private let windowHeight: CGFloat = 105
    private let cornerRadius: CGFloat = 12

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            switch previewMode {
            case .hidden:
                // Minimal dot indicator showing swipe is available
                HStack(spacing: 4) {
                    ForEach(PreviewMode.allCases, id: \.rawValue) { mode in
                        Circle()
                            .fill(mode == previewMode ? theme.primaryColor.opacity(0.5) : theme.primaryColor.opacity(0.15))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: windowWidth, height: 20)

            case .camera:
                previewWindow {
                    if let image {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: windowWidth, height: windowHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(theme.primaryColor.opacity(0.05))
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                    .foregroundStyle(theme.primaryColor.opacity(0.2))
                            }
                    }
                }

            case .histogram:
                previewWindow {
                    HistogramView(bins: histogramBins)
                        .padding(8)
                }
            }
        }
        .offset(x: dragOffset)
        .gesture(swipeGesture)
        .animation(.spring(duration: 0.35), value: previewMode)
        .animation(.spring(duration: 0.2), value: dragOffset)
        .accessibilityIdentifier("scenePreview")
    }

    // MARK: - Preview Window Chrome

    @ViewBuilder
    private func previewWindow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(width: windowWidth, height: windowHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(theme.primaryColor.opacity(0.12), lineWidth: 0.5)
                )

            // Page dots
            HStack(spacing: 4) {
                ForEach(PreviewMode.allCases, id: \.rawValue) { mode in
                    Circle()
                        .fill(mode == previewMode ? theme.primaryColor.opacity(0.5) : theme.primaryColor.opacity(0.15))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width * 0.3
            }
            .onEnded { value in
                dragOffset = 0
                let threshold: CGFloat = 30
                if value.translation.width < -threshold {
                    // Swipe left → next mode
                    withAnimation(.spring(duration: 0.35)) {
                        previewMode = previewMode.next
                    }
                } else if value.translation.width > threshold {
                    // Swipe right → previous mode
                    withAnimation(.spring(duration: 0.35)) {
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
    .preferredColorScheme(.dark)
}
