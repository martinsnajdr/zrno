import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<CameraProfile> { $0.isSelected })
    private var selectedProfiles: [CameraProfile]
    @Query private var allProfiles: [CameraProfile]

    @State private var lightMeter = LightMeterService()
    @State private var theme = AppTheme()
    @State private var showProfileList = false
    @State private var showISOPicker = false
    @State private var showSettings = false
    @State private var isEditingLayout = false
    @State private var layoutOffsets = LayoutOffsets.load()
    @AppStorage("zrno.previewMode") private var previewMode: PreviewMode = .histogram

    private var activeProfile: CameraProfile? { selectedProfiles.first }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Solid theme background
                theme.backgroundColor.ignoresSafeArea()

                meterContent

                // Top bar: profiles | ZRNO | settings
                VStack {
                    HStack {
                        // Camera profiles (left)
                        if !isEditingLayout {
                            Button {
                                showProfileList = true
                            } label: {
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(theme.primaryColor)
                                    .frame(width: 40, height: 40)
                                    .background(theme.primaryColor.opacity(0.06), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("profileButton")
                        }

                        Spacer()

                        // Branding (non-interactive)
                        Text("ZRNO")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.primaryColor)
                            .tracking(4)

                        Spacer()

                        // Settings (right)
                        if !isEditingLayout {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(theme.primaryColor)
                                    .frame(width: 40, height: 40)
                                    .background(theme.primaryColor.opacity(0.06), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settingsButton")
                        }

                        // Edit mode done button
                        if isEditingLayout {
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(duration: 0.3)) {
                                    isEditingLayout = false
                                    layoutOffsets.save()
                                }
                            }
                            .font(.system(size: 15, weight: .semibold, design: theme.design))
                            .foregroundStyle(theme.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(theme.primaryColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .transition(.opacity)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .environment(\.appTheme, theme)
        .preferredColorScheme(theme.appearanceMode.colorScheme)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            ensureDefaultProfile()
            updateEffectiveAppearance()
            Task {
                await lightMeter.requestPermission()
                lightMeter.startMetering()
            }
        }
        .onChange(of: lightMeter.measuredEV) {
            if let profile = activeProfile {
                lightMeter.updateRecommendation(for: profile)
            }
        }
        .onChange(of: allProfiles.count) {
            if let profile = activeProfile {
                lightMeter.updateRecommendation(for: profile, force: true)
            }
        }
        .onChange(of: activeProfile?.exposureCompensation) { _, _ in
            if let profile = activeProfile {
                lightMeter.updateRecommendation(for: profile, force: true)
            }
        }
        .onChange(of: activeProfile?.filmISO) { _, _ in
            if let profile = activeProfile {
                lightMeter.updateRecommendation(for: profile, force: true)
            }
        }
        .onChange(of: activeProfile?.cameraType) { _, _ in
            // Reset priority modes when switching camera type
            if activeProfile?.type == .pinhole, lightMeter.meterMode != .auto {
                lightMeter.meterMode = .auto
                lightMeter.lockedAperture = nil
                lightMeter.lockedShutterSpeed = nil
            }
            if let profile = activeProfile {
                lightMeter.updateRecommendation(for: profile, force: true)
            }
        }
        .sheet(isPresented: $showProfileList) {
            ProfileListView()
                .environment(\.appTheme, theme)
        }
        .sheet(isPresented: $showISOPicker) {
            ISOPickerView(profile: activeProfile)
                .environment(\.appTheme, theme)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(\.appTheme, theme)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.3)) {
                        isEditingLayout = true
                    }
                }
        )
        .onChange(of: colorScheme) { _, _ in
            updateEffectiveAppearance()
        }
        .onChange(of: theme.appearanceMode) { _, _ in
            updateEffectiveAppearance()
        }
    }

    @ViewBuilder
    private var meterContent: some View {
        if lightMeter.permissionGranted {
            DraggableContainer(isEditing: $isEditingLayout, offsets: $layoutOffsets) {
                MeterView(
                    aperture: lightMeter.recommendedAperture,
                    shutterSpeed: lightMeter.recommendedShutterSpeed,
                    iso: activeProfile?.filmISO ?? 400,
                    meterReliability: lightMeter.meterReliability,
                    exposureStatus: lightMeter.exposureStatus,
                    profileName: activeProfile?.name ?? "",
                    compensation: Binding(
                        get: { activeProfile?.exposureCompensation ?? 0 },
                        set: { activeProfile?.exposureCompensation = $0 }
                    ),
                    meterMode: lightMeter.meterMode,
                    availableApertures: activeProfile?.activeApertures ?? [],
                    availableShutterSpeeds: activeProfile?.sortedShutterSpeeds ?? [],
                    lenses: activeProfile?.lenses ?? [],
                    cameras: lightMeter.availableCameras,
                    activeCameraID: lightMeter.activeCameraID,
                    previewImage: lightMeter.previewImage,
                    histogramBins: lightMeter.histogramBins,
                    previewMode: $previewMode,
                    onISOTap: { showISOPicker = true },
                    onApertureLock: {
                        lightMeter.toggleAperturePriority(currentAperture: lightMeter.recommendedAperture)
                        if let profile = activeProfile {
                            lightMeter.updateRecommendation(for: profile, force: true)
                        }
                    },
                    onShutterLock: {
                        lightMeter.toggleShutterPriority(currentShutter: lightMeter.recommendedShutterSpeed)
                        if let profile = activeProfile {
                            lightMeter.updateRecommendation(for: profile, force: true)
                        }
                    },
                    isPinholeMode: lightMeter.isPinholeMode,
                    pinholeFilmStock: activeProfile?.type == .pinhole ? (activeProfile?.filmPreset ?? "") : "",
                    uncorrectedShutterSpeed: lightMeter.uncorrectedShutterSpeed,
                    onApertureSelect: { value in
                        lightMeter.setLockedAperture(value)
                        if let profile = activeProfile {
                            lightMeter.updateRecommendation(for: profile, force: true)
                        }
                    },
                    onShutterSelect: { value in
                        lightMeter.setLockedShutterSpeed(value)
                        if let profile = activeProfile {
                            lightMeter.updateRecommendation(for: profile, force: true)
                        }
                    },
                    onLensSelect: { lens in
                        guard let profile = activeProfile else { return }
                        for l in profile.lenses { l.isSelected = false }
                        lens.isSelected = true
                        lightMeter.selectClosestCamera(toFocalLength: lens.focalLength)
                        lightMeter.updateRecommendation(for: profile, force: true)
                    },
                    onCameraSelect: { camera in
                        lightMeter.switchCamera(to: camera)
                    }
                )
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.primaryColor.opacity(0.3))
                Text("Camera access is required\nto measure light")
                    .font(.system(size: 17, weight: .medium, design: theme.design))
                    .foregroundStyle(theme.secondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func ensureDefaultProfile() {
        // Migrate old profiles: mark "Mamiya 7" / "35mm Camera" as non-default user profiles
        if let old = allProfiles.first(where: { $0.name == "35mm Camera" }) {
            old.name = "Mamiya 7"
            if old.lenses.isEmpty {
                let defaultLens = Lens(
                    name: "N 80mm f/4 L",
                    focalLength: 80,
                    apertures: [4.0, 5.6, 8.0, 11.0, 16.0, 22.0],
                    isSelected: true
                )
                defaultLens.cameraProfile = old
                modelContext.insert(defaultLens)
            }
        }

        // Ensure the built-in "Basic" profile exists
        let hasDefault = allProfiles.contains { $0.isDefault }
        if !hasDefault {
            let generic = CameraProfile(
                name: "Basic",
                filmISO: 400,
                isSelected: allProfiles.isEmpty
            )
            generic.isDefault = true
            modelContext.insert(generic)

            let genericLens = Lens(
                name: "–",
                focalLength: 50,
                apertures: CameraProfile.basicApertures,
                isSelected: true
            )
            genericLens.cameraProfile = generic
            modelContext.insert(genericLens)
        }

        // Always reset Basic profile to hardcoded values
        if let basic = allProfiles.first(where: { $0.isDefault }) {
            basic.name = "Basic"
            basic.apertures = CameraProfile.basicApertures
            basic.shutterSpeeds = CameraProfile.basicShutterSpeeds
            for lens in basic.lenses {
                lens.name = "–"
                lens.apertures = CameraProfile.basicApertures
            }
        }
    }

    private func updateEffectiveAppearance() {
        switch theme.appearanceMode {
        case .dark:
            theme.effectiveIsDark = true
        case .light:
            theme.effectiveIsDark = false
        case .system:
            theme.effectiveIsDark = (colorScheme == .dark)
        }
    }
}

// MARK: - Layout Persistence

struct LayoutOffsets: Codable {
    var meterOffsetX: CGFloat = 0
    var meterOffsetY: CGFloat = 0

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "zrno.layout")
        }
    }

    static func load() -> LayoutOffsets {
        guard let data = UserDefaults.standard.data(forKey: "zrno.layout"),
              let offsets = try? JSONDecoder().decode(LayoutOffsets.self, from: data) else {
            return LayoutOffsets()
        }
        return offsets
    }
}

// MARK: - Draggable Container

struct DraggableContainer<Content: View>: View {
    @Binding var isEditing: Bool
    @Binding var offsets: LayoutOffsets
    @ViewBuilder let content: Content

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        content
            .offset(
                x: offsets.meterOffsetX + (isEditing ? dragOffset.width : 0),
                y: offsets.meterOffsetY + (isEditing ? dragOffset.height : 0)
            )
            .overlay {
                if isEditing {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        .padding(-16)
                }
            }
            .gesture(isEditing ? drag : nil)
            .animation(.spring(duration: 0.25), value: isEditing)
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                offsets.meterOffsetX += value.translation.width
                offsets.meterOffsetY += value.translation.height
                dragOffset = .zero
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CameraProfile.self, Lens.self], inMemory: true)
}
