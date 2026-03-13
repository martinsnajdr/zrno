import SwiftUI

struct MeterView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    let aperture: Double
    let shutterSpeed: Double
    let iso: Int
    let measuredEV: Double
    let focalLength: String
    @Binding var compensation: Double
    let meterMode: MeterMode
    let availableApertures: [Double]
    let availableShutterSpeeds: [Double]
    let lenses: [Lens]
    let previewImage: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode
    let activeCameraLabel: String
    let onISOTap: () -> Void
    let onApertureLock: () -> Void
    let onShutterLock: () -> Void
    let onApertureSelect: (Double) -> Void
    let onShutterSelect: (Double) -> Void
    let onLensSelect: (Lens) -> Void

    private var isApertureLocked: Bool { meterMode == .aperturePriority }
    private var isShutterLocked: Bool { meterMode == .shutterPriority }
    private var isLandscape: Bool { vSizeClass == .compact }

    private var selectedLensName: String? {
        lenses.first(where: { $0.isSelected })?.name
    }

    var body: some View {
        if isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            exposureControls

            Spacer().frame(height: 20)

            CompensationDialView(compensation: $compensation)

            Spacer().frame(height: 12)

            ScenePreviewView(
                image: previewImage,
                histogramBins: histogramBins,
                previewMode: $previewMode
            )
            .padding(.horizontal, 20)

            Spacer().frame(height: 12)

            bottomBar
                .padding(.bottom, 50)
        }
        .animation(.spring(duration: 0.4), value: aperture)
        .animation(.spring(duration: 0.4), value: shutterSpeed)
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left: exposure readings + compensation
            VStack(spacing: 0) {
                Spacer()
                exposureControls
                Spacer().frame(height: 16)
                CompensationDialView(compensation: $compensation)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Right: preview + info
            VStack(spacing: 0) {
                Spacer()

                ScenePreviewView(
                    image: previewImage,
                    histogramBins: histogramBins,
                    previewMode: $previewMode
                )

                Spacer().frame(height: 16)

                bottomBar

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .animation(.spring(duration: 0.4), value: aperture)
        .animation(.spring(duration: 0.4), value: shutterSpeed)
    }

    // MARK: - Shared Components

    private var exposureControls: some View {
        VStack(spacing: 0) {
            // Aperture
            Button(action: onApertureLock) {
                HStack(spacing: 6) {
                    if isApertureLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accentColor)
                    }
                    Text(ExposureCalculator.formatAperture(aperture))
                        .font(.system(size: 44, weight: .ultraLight, design: theme.design))
                        .foregroundStyle(isApertureLocked ? theme.primaryColor : theme.primaryColor.opacity(0.85))
                        .contentTransition(.numericText(value: aperture))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("apertureLabel")

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

            Spacer().frame(height: 2)

            // Shutter speed
            Button(action: onShutterLock) {
                HStack(spacing: 8) {
                    if isShutterLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.accentColor)
                    }
                    Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                        .font(.system(size: 72, weight: .bold, design: theme.design))
                        .foregroundStyle(theme.primaryColor)
                        .contentTransition(.numericText(value: shutterSpeed))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shutterSpeedLabel")

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

            Spacer().frame(height: 8)

            // EV + focal length
            HStack(spacing: 12) {
                Text("EV \(ExposureCalculator.formatEV(measuredEV))")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
                    .accessibilityIdentifier("evLabel")

                if !focalLength.isEmpty {
                    Text(focalLength)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Camera info line
            if !activeCameraLabel.isEmpty {
                Text(activeCameraLabel)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
            }

            // ISO + selected lens name
            HStack(spacing: 12) {
                Button(action: onISOTap) {
                    Text("ISO \(iso, format: .number.grouping(.never))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(theme.primaryColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("isoButton")

                if let lensName = selectedLensName {
                    Text(lensName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }
            }

            // Lens selector (swipeable) — show when multiple lenses
            if lenses.count > 1 {
                lensSelector
            }
        }
    }

    @ViewBuilder
    private var lensSelector: some View {
        let sorted = lenses.sorted(by: { $0.focalLength < $1.focalLength })
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sorted) { lens in
                    Button {
                        onLensSelect(lens)
                    } label: {
                        Text("\(lens.focalLength)mm")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                lens.isSelected ? theme.accentColor : theme.secondaryColor
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                lens.isSelected
                                    ? theme.primaryColor.opacity(0.12)
                                    : theme.primaryColor.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MeterView(
            aperture: 5.6,
            shutterSpeed: 1.0 / 125,
            iso: 400,
            measuredEV: 12.3,
            focalLength: "80mm",
            compensation: .constant(0.0),
            meterMode: .auto,
            availableApertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            availableShutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15],
            lenses: [],
            previewImage: nil,
            histogramBins: (0..<256).map { i in
                let center: Float = 128
                let spread: Float = 45
                let dist = Float(i) - center
                return exp(-(dist * dist) / (2 * spread * spread))
            },
            previewMode: .constant(.histogram),
            activeCameraLabel: "26mm",
            onISOTap: {},
            onApertureLock: {},
            onShutterLock: {},
            onApertureSelect: { _ in },
            onShutterSelect: { _ in },
            onLensSelect: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
