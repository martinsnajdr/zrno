import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var previewMode: PreviewMode = .hidden

    private var activeProfile: CameraProfile? { selectedProfiles.first }

    var body: some View {
        ZStack {
            // Solid theme background (no fullscreen camera preview)
            theme.backgroundColor.ignoresSafeArea()

            if lightMeter.isRunning || !lightMeter.permissionGranted {
                meterContent
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(theme.secondaryColor)
                    Text("Starting meter...")
                        .font(.system(size: 15, weight: .medium, design: theme.design))
                        .foregroundStyle(theme.secondaryColor)
                }
            }

            // Top controls
            VStack {
                HStack {
                    // Camera selector
                    if lightMeter.availableCameras.count > 1 {
                        CameraSelectorView(
                            cameras: lightMeter.availableCameras,
                            activeCameraID: lightMeter.activeCameraID,
                            onSelect: { lens in
                                lightMeter.switchCamera(to: lens)
                            }
                        )
                    }

                    Spacer()

                    // Settings button
                    if !isEditingLayout {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.primaryColor.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .background(theme.primaryColor.opacity(0.08), in: Circle())
                        }
                        .accessibilityIdentifier("settingsButton")
                    }

                    // Edit mode done button
                    if isEditingLayout {
                        Button("Done") {
                            withAnimation(.spring(duration: 0.3)) {
                                isEditingLayout = false
                                layoutOffsets.save()
                            }
                        }
                        .font(.system(size: 17, weight: .semibold, design: theme.design))
                        .foregroundStyle(theme.primaryColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(theme.primaryColor.opacity(0.15), in: Capsule())
                        .transition(.opacity)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .environment(\.appTheme, theme)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            ensureDefaultProfile()
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
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring(duration: 0.3)) {
                isEditingLayout = true
            }
        }
    }

    @ViewBuilder
    private var meterContent: some View {
        if lightMeter.permissionGranted {
            DraggableContainer(isEditing: $isEditingLayout, offsets: $layoutOffsets) {
                MeterView(
                    ev: lightMeter.measuredEV,
                    aperture: lightMeter.recommendedAperture,
                    shutterSpeed: lightMeter.recommendedShutterSpeed,
                    iso: activeProfile?.filmISO ?? 400,
                    profileName: activeProfile?.name ?? "No Camera",
                    compensation: Binding(
                        get: { activeProfile?.exposureCompensation ?? 0 },
                        set: { activeProfile?.exposureCompensation = $0 }
                    ),
                    meterMode: lightMeter.meterMode,
                    focusPosition: lightMeter.focusPosition,
                    availableApertures: activeProfile?.sortedApertures ?? [],
                    availableShutterSpeeds: activeProfile?.sortedShutterSpeeds ?? [],
                    previewImage: lightMeter.previewImage,
                    histogramBins: lightMeter.histogramBins,
                    previewMode: $previewMode,
                    onISOTap: { showISOPicker = true },
                    onProfileTap: { showProfileList = true },
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
        guard allProfiles.isEmpty else { return }
        let defaultProfile = CameraProfile(
            name: "35mm Camera",
            apertures: [2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            shutterSpeeds: [
                1.0 / 1000, 1.0 / 500, 1.0 / 250, 1.0 / 125,
                1.0 / 60, 1.0 / 30, 1.0 / 15, 1.0 / 8,
                1.0 / 4, 1.0 / 2, 1.0
            ],
            filmISO: 400,
            isSelected: true
        )
        modelContext.insert(defaultProfile)
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
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
        .modelContainer(for: CameraProfile.self, inMemory: true)
}
