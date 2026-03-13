import SwiftUI

struct ScenePreviewView: View {
    let image: CGImage?
    let histogramBins: [Float]
    @Binding var showHistogram: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Lo-fi monochrome camera preview
                if let image {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.2)
                        .blur(radius: 1)
                } else {
                    Color.black
                }

                // Subtle noise/grain overlay for film aesthetic
                Color.black.opacity(0.15)

                // Histogram overlay
                if showHistogram {
                    VStack {
                        Spacer()
                        HistogramView(bins: histogramBins)
                            .frame(height: 70)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 140)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
