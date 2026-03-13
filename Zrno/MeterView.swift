import SwiftUI

struct MeterView: View {
    @Environment(\.appTheme) private var theme

    let ev: Double
    let aperture: Double
    let shutterSpeed: Double
    let iso: Int
    let profileName: String
    @Binding var compensation: Double
    let meterMode: MeterMode
    let focusPosition: Float
    let availableApertures: [Double]
    let availableShutterSpeeds: [Double]
    let previewImage: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode
    let onISOTap: () -> Void
    let onProfileTap: () -> Void
    let onApertureLock: () -> Void
    let onShutterLock: () -> Void
    let onApertureSelect: (Double) -> Void
    let onShutterSelect: (Double) -> Void

    private var isApertureLocked: Bool { meterMode == .aperturePriority }
    private var isShutterLocked: Bool { meterMode == .shutterPriority }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Aperture — tappable for priority lock
            Button(action: onApertureLock) {
                HStack(spacing: 6) {
                    if isApertureLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accentColor)
                    }
                    Text(ExposureCalculator.formatAperture(aperture))
                        .font(.system(size: 54, weight: .ultraLight, design: theme.design))
                        .foregroundStyle(isApertureLocked ? theme.primaryColor : theme.primaryColor.opacity(0.85))
                        .contentTransition(.numericText(value: aperture))
                }
            }
            .accessibilityIdentifier("apertureLabel")

            // Aperture value picker (visible in aperture priority)
            if isApertureLocked {
                PriorityValuePicker(
                    values: availableApertures,
                    selectedValue: aperture,
                    formatter: ExposureCalculator.formatAperture,
                    onSelect: onApertureSelect
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 4)
            }

            Spacer().frame(height: 4)

            // Shutter speed — tappable for priority lock
            Button(action: onShutterLock) {
                HStack(spacing: 8) {
                    if isShutterLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(theme.accentColor)
                    }
                    Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                        .font(.system(size: 96, weight: .bold, design: theme.design))
                        .foregroundStyle(theme.primaryColor)
                        .contentTransition(.numericText(value: shutterSpeed))
                }
            }
            .accessibilityIdentifier("shutterSpeedLabel")

            // Shutter speed value picker (visible in shutter priority)
            if isShutterLocked {
                PriorityValuePicker(
                    values: availableShutterSpeeds,
                    selectedValue: shutterSpeed,
                    formatter: ExposureCalculator.formatShutterSpeed,
                    onSelect: onShutterSelect
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 4)
            }

            Spacer().frame(height: 16)

            // EV + focus distance row
            HStack(spacing: 16) {
                Text("EV \(ExposureCalculator.formatEV(ev))")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
                    .contentTransition(.numericText(value: ev))
                    .accessibilityIdentifier("evLabel")

                FocusIndicator(position: focusPosition, theme: theme)
            }

            Spacer().frame(height: 24)

            // Exposure compensation dial
            CompensationDialView(compensation: $compensation)

            Spacer().frame(height: 20)

            // Preview / Histogram — swipeable, replaces the old exposure table
            ScenePreviewView(
                image: previewImage,
                histogramBins: histogramBins,
                previewMode: $previewMode
            )
            .accessibilityIdentifier("scenePreview")

            Spacer()

            // Bottom bar — ISO and camera profile
            HStack(spacing: 16) {
                Button(action: onISOTap) {
                    Text("ISO \(iso)")
                        .font(.system(size: 15, weight: .semibold, design: theme.design))
                        .foregroundStyle(theme.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.primaryColor.opacity(0.08), in: Capsule())
                }
                .accessibilityIdentifier("isoButton")

                Button(action: onProfileTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 12))
                        Text(profileName)
                            .font(.system(size: 15, weight: .medium, design: theme.design))
                    }
                    .foregroundStyle(theme.secondaryColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.primaryColor.opacity(0.05), in: Capsule())
                }
                .accessibilityIdentifier("profileButton")
            }
            .padding(.bottom, 50)
        }
        .animation(.spring(duration: 0.4), value: ev)
    }
}

// MARK: - Focus Indicator

private struct FocusIndicator: View {
    let position: Float // 0.0 = near, 1.0 = far
    let theme: AppTheme

    private var label: String {
        switch position {
        case 0.0..<0.15: return "●"
        case 0.15..<0.4: return "◐"
        case 0.4..<0.75: return "○"
        default: return "∞"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // Small focus distance bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.primaryColor.opacity(0.1))
                    Capsule()
                        .fill(theme.primaryColor.opacity(0.3))
                        .frame(width: max(4, geo.size.width * CGFloat(position)))
                }
            }
            .frame(width: 30, height: 4)

            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(theme.secondaryColor)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MeterView(
            ev: 12.3,
            aperture: 5.6,
            shutterSpeed: 1.0 / 125,
            iso: 400,
            profileName: "Leica M6",
            compensation: .constant(0.0),
            meterMode: .auto,
            focusPosition: 0.7,
            availableApertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            availableShutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15],
            previewImage: nil,
            histogramBins: Array(repeating: Float(0), count: 256),
            previewMode: .constant(.hidden),
            onISOTap: {},
            onProfileTap: {},
            onApertureLock: {},
            onShutterLock: {},
            onApertureSelect: { _ in },
            onShutterSelect: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
