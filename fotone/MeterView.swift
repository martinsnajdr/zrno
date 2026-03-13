import SwiftUI

struct MeterView: View {
    let ev: Double
    let aperture: Double
    let shutterSpeed: Double
    let iso: Int
    let profileName: String
    let combinations: [(aperture: Double, shutterSpeed: Double)]
    let onISOTap: () -> Void
    let onProfileTap: () -> Void

    @State private var showTable = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Aperture — light, elegant
            Text(ExposureCalculator.formatAperture(aperture))
                .font(.system(size: 54, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText(value: aperture))

            Spacer().frame(height: 4)

            // Shutter speed — the hero
            Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: shutterSpeed))

            Spacer().frame(height: 20)

            // EV reading — subdued
            Text("EV \(ExposureCalculator.formatEV(ev))")
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .contentTransition(.numericText(value: ev))

            Spacer()

            // Exposure table toggle
            if !combinations.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        showTable.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showTable ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Exposure Table")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.bottom, 8)
            }

            // Exposure combinations table
            if showTable {
                ExposureTableView(combinations: combinations, recommended: (aperture, shutterSpeed))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }

            Spacer()

            // Bottom bar — ISO and camera profile
            HStack(spacing: 16) {
                Button(action: onISOTap) {
                    Text("ISO \(iso)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: Capsule())
                }

                Button(action: onProfileTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 12))
                        Text(profileName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.05), in: Capsule())
                }
            }
            .padding(.bottom, 50)
        }
        .animation(.spring(duration: 0.4), value: ev)
    }
}
