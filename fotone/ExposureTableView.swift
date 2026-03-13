import SwiftUI

struct ExposureTableView: View {
    let combinations: [(aperture: Double, shutterSpeed: Double)]
    let recommended: (aperture: Double, shutterSpeed: Double)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(combinations.enumerated()), id: \.offset) { _, combo in
                let isRecommended = abs(combo.aperture - recommended.0) < 0.01
                    && abs(combo.shutterSpeed - recommended.1) < 0.0001

                HStack {
                    Text(ExposureCalculator.formatAperture(combo.aperture))
                        .font(.system(size: 16, weight: isRecommended ? .semibold : .regular, design: .monospaced))
                        .frame(width: 60, alignment: .trailing)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 8)

                    Text(ExposureCalculator.formatShutterSpeed(combo.shutterSpeed))
                        .font(.system(size: 16, weight: isRecommended ? .semibold : .regular, design: .monospaced))
                        .frame(width: 80, alignment: .leading)
                }
                .foregroundStyle(isRecommended ? .white : .white.opacity(0.5))
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 40)
    }
}
