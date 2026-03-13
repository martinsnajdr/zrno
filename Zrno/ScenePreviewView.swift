import SwiftUI

/// A small window that cycles between hidden / camera preview / histogram via swipe or tap.
struct ScenePreviewView: View {
    @Environment(\.appTheme) private var theme

    let image: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode

    private let windowWidth: CGFloat = 160
    private let windowHeight: CGFloat = 100
    private let cornerRadius: CGFloat = 8

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            Group {
                switch previewMode {
                case .hidden:
                    // Tappable placeholder — tap to cycle to camera
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: windowWidth, height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                previewMode = previewMode.next
                            }
                        }

                case .camera:
                    cameraContent
                        .frame(width: windowWidth, height: windowHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(theme.primaryColor.opacity(0.12), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                previewMode = previewMode.next
                            }
                        }

                case .histogram:
                    HistogramView(bins: histogramBins)
                        .frame(width: windowWidth, height: windowHeight)
                        .padding(8)
                        .background(theme.primaryColor.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(theme.primaryColor.opacity(0.12), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                previewMode = previewMode.next
                            }
                        }
                }
            }
            .offset(x: dragOffset)
            .gesture(swipeGesture)

            // Page dots — always visible, tappable
            HStack(spacing: 6) {
                ForEach(PreviewMode.allCases, id: \.rawValue) { mode in
                    Circle()
                        .fill(mode == previewMode ? theme.primaryColor.opacity(0.6) : theme.primaryColor.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    previewMode = previewMode.next
                }
            }
        }
        .animation(.spring(duration: 0.3), value: previewMode)
        .animation(.spring(duration: 0.2), value: dragOffset)
    }

    // MARK: - Camera Content

    @ViewBuilder
    private var cameraContent: some View {
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
            previewMode: .constant(.camera)
        )
    }
}
