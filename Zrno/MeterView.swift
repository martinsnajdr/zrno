import SwiftUI

struct MeterView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    let aperture: Double
    let shutterSpeed: Double
    let iso: Int
    let measuredEV: Double
    let focusDistance: String
    let profileName: String
    @Binding var compensation: Double
    let meterMode: MeterMode
    let availableApertures: [Double]
    let availableShutterSpeeds: [Double]
    let lenses: [Lens]
    let cameras: [CameraLens]
    let activeCameraID: String
    let previewImage: CGImage?
    let histogramBins: [Float]
    @Binding var previewMode: PreviewMode
    let onISOTap: () -> Void
    let onApertureLock: () -> Void
    let onShutterLock: () -> Void
    let onApertureSelect: (Double) -> Void
    let onShutterSelect: (Double) -> Void
    let onLensSelect: (Lens) -> Void
    let onCameraSelect: (CameraLens) -> Void

    private var isApertureLocked: Bool { meterMode == .aperturePriority }
    private var isShutterLocked: Bool { meterMode == .shutterPriority }
    private var isLandscape: Bool { vSizeClass == .compact }

    private var selectedLensName: String? {
        lenses.first(where: { $0.isSelected })?.name
    }

    private var activeCameraLabel: String? {
        cameras.first(where: { $0.id == activeCameraID })?.label
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
            Spacer().frame(height: 76)

            exposureControls

            Spacer().frame(height: 12)

            CompensationDialView(compensation: $compensation)

            Spacer().frame(height: 16)

            ScenePreviewView(
                image: previewImage,
                histogramBins: histogramBins,
                previewMode: $previewMode
            )
            .padding(.horizontal, 20)

            Spacer().frame(height: 20)

            bottomBar
                .padding(.bottom, 30)
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
            // Aperture — tap to lock, inline picker when locked
            if isApertureLocked {
                PriorityValuePicker(
                    values: availableApertures,
                    selectedValue: aperture,
                    formatter: ExposureCalculator.formatAperture,
                    onSelect: onApertureSelect,
                    font: .system(size: 44, weight: .ultraLight, design: theme.design),
                    onTapSelected: onApertureLock
                )
                .frame(height: 52)
                .overlay(alignment: .leading) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accentColor)
                        .padding(.leading, 6)
                }
                .accessibilityIdentifier("apertureLabel")
            } else {
                Button(action: onApertureLock) {
                    Text(ExposureCalculator.formatAperture(aperture))
                        .font(.system(size: 44, weight: .ultraLight, design: theme.design))
                        .foregroundStyle(theme.primaryColor.opacity(0.85))
                        .contentTransition(.numericText(value: aperture))
                }
                .buttonStyle(.plain)
                .frame(height: 52)
                .accessibilityIdentifier("apertureLabel")
            }

            // Shutter speed — tap to lock, inline picker when locked
            if isShutterLocked {
                PriorityValuePicker(
                    values: availableShutterSpeeds,
                    selectedValue: shutterSpeed,
                    formatter: ExposureCalculator.formatShutterSpeed,
                    onSelect: onShutterSelect,
                    font: .system(size: 78, weight: .bold, design: theme.design),
                    onTapSelected: onShutterLock
                )
                .frame(height: 90)
                .overlay(alignment: .leading) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accentColor)
                        .padding(.leading, 6)
                }
                .accessibilityIdentifier("shutterSpeedLabel")
            } else {
                Button(action: onShutterLock) {
                    Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                        .font(.system(size: 78, weight: .bold, design: theme.design))
                        .foregroundStyle(theme.primaryColor)
                        .contentTransition(.numericText(value: shutterSpeed))
                }
                .buttonStyle(.plain)
                .frame(height: 90)
                .accessibilityIdentifier("shutterSpeedLabel")
            }

            Spacer().frame(height: 8)

            // EV + focus distance
            HStack(spacing: 12) {
                Text("EV \(ExposureCalculator.formatEV(measuredEV))")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
                    .accessibilityIdentifier("evLabel")

                if !focusDistance.isEmpty {
                    Text(focusDistance)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Profile name
            if !profileName.isEmpty {
                Text(profileName)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.primaryColor)
            }

            // Lens name (swipeable if multiple)
            if lenses.count > 1 {
                lensSwiper
            } else if let lensName = selectedLensName {
                Text(lensName)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.primaryColor.opacity(0.7))
            }

            // ISO
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

            // iPhone camera
            if cameras.count > 1 {
                CameraSelectorView(
                    cameras: cameras,
                    activeCameraID: activeCameraID,
                    onSelect: onCameraSelect
                )
            } else if let cameraLabel = activeCameraLabel {
                Text("iPhone \(cameraLabel)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
            }
        }
    }

    private var lensSwiper: some View {
        lensSwiperContent
    }

    @ViewBuilder
    private var lensSwiperContent: some View {
        let sorted = lenses.sorted(by: { $0.focalLength < $1.focalLength })
        let currentIndex = sorted.firstIndex(where: { $0.isSelected }) ?? 0
        let currentLens = sorted[currentIndex]

        HStack(spacing: 6) {
            if sorted.count > 1 {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondaryColor.opacity(currentIndex > 0 ? 1 : 0.3))
            }

            Text(currentLens.name)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.primaryColor.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: currentLens.name)

            if sorted.count > 1 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondaryColor.opacity(currentIndex < sorted.count - 1 ? 1 : 0.3))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if value.translation.width < -20, currentIndex < sorted.count - 1 {
                            onLensSelect(sorted[currentIndex + 1])
                        } else if value.translation.width > 20, currentIndex > 0 {
                            onLensSelect(sorted[currentIndex - 1])
                        }
                    }
                }
        )
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
            focusDistance: "1.2m",
            profileName: "Mamiya 7",
            compensation: .constant(0.0),
            meterMode: .auto,
            availableApertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            availableShutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15],
            lenses: [],
            cameras: [],
            activeCameraID: "",
            previewImage: nil,
            histogramBins: (0..<256).map { i in
                let center: Float = 128
                let spread: Float = 45
                let dist = Float(i) - center
                return exp(-(dist * dist) / (2 * spread * spread))
            },
            previewMode: .constant(.histogram),
            onISOTap: {},
            onApertureLock: {},
            onShutterLock: {},
            onApertureSelect: { _ in },
            onShutterSelect: { _ in },
            onLensSelect: { _ in },
            onCameraSelect: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
