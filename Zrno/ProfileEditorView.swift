import SwiftUI
import SwiftData

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let profile: CameraProfile?

    @State private var name: String = ""
    @State private var filmISO: Int = 400
    @State private var selectedShutterSpeeds: Set<Double> = []
    @State private var compensation: Double = 0.0
    @State private var calibrationEntries: [Double: String] = [:] // nominal speed → actual reciprocal text
    @State private var showAddLens = false
    @State private var editingLens: Lens?

    private let standardShutterSpeeds: [Double] = ExposureCalculator.standardShutterSpeeds

    private var isEditing: Bool { profile != nil }

    private var sortedLenses: [Lens] {
        (profile?.lenses ?? []).sorted { $0.focalLength < $1.focalLength }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Camera Name
                    sheetSection("Camera Name") {
                        sheetRow(isLast: true) {
                            TextField("e.g. Leica M6", text: $name)
                                .font(.system(size: 15, weight: .regular, design: .monospaced))
                                .foregroundStyle(theme.primaryColor)
                        }
                    }

                    // Lenses (only when editing)
                    if isEditing {
                        sheetSection("Lenses") {
                            let lenses = sortedLenses
                            ForEach(Array(lenses.enumerated()), id: \.element.id) { index, lens in
                                sheetRow(isLast: index == lenses.count - 1 && lenses.count > 0) {
                                    HStack(spacing: 12) {
                                        // Checkmark circle
                                        Button {
                                            // Select this lens
                                            for l in profile?.lenses ?? [] {
                                                l.isSelected = (l.id == lens.id)
                                            }
                                        } label: {
                                            Image(systemName: lens.isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20, weight: .regular))
                                                .foregroundStyle(lens.isSelected ? theme.primaryColor : theme.secondaryColor.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)

                                        // Name + info (tappable to edit)
                                        Button {
                                            editingLens = lens
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lens.name)
                                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(theme.primaryColor)
                                                Text("\(lens.focalLength)mm · \(lens.apertures.count) apertures")
                                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                                    .foregroundStyle(theme.secondaryColor)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        // Edit
                                        Button {
                                            editingLens = lens
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(theme.secondaryColor)
                                                .frame(width: 30, height: 30)
                                                .background(
                                                    Circle()
                                                        .fill(theme.backgroundColor)
                                                )
                                        }
                                        .buttonStyle(PressableButtonStyle())

                                        // Delete
                                        Button {
                                            if let profile {
                                                profile.lenses.removeAll { $0.id == lens.id }
                                                modelContext.delete(lens)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(theme.secondaryColor)
                                                .frame(width: 30, height: 30)
                                                .background(
                                                    Circle()
                                                        .fill(theme.backgroundColor)
                                                )
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                            }

                            // Add Lens button
                            if !lenses.isEmpty {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(theme.primaryColor.opacity(0.08))
                                        .frame(height: 0.5)
                                        .padding(.leading, 14)
                                    Button {
                                        showAddLens = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("Add Lens")
                                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                        }
                                        .foregroundStyle(theme.primaryColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                sheetRow(isLast: true) {
                                    Button {
                                        showAddLens = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("Add Lens")
                                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                        }
                                        .foregroundStyle(theme.primaryColor)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text("Each lens defines its own set of apertures.")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.secondaryColor)
                            .padding(.leading, 4)
                            .padding(.top, -18)
                    }

                    // Shutter Speeds
                    sheetSection("Available Shutter Speeds") {
                        sheetRow(isLast: true) {
                            shutterSpeedGrid
                        }
                    }

                    Text("Select the shutter speeds your camera supports.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                        .padding(.leading, 4)
                        .padding(.top, -18)

                    // Calibration
                    if !selectedShutterSpeeds.isEmpty {
                        sheetSection("Speed Calibration") {
                            let speeds = Array(selectedShutterSpeeds).sorted()
                            ForEach(Array(speeds.enumerated()), id: \.element) { index, speed in
                                sheetRow(isLast: index == speeds.count - 1) {
                                    HStack(spacing: 12) {
                                        Text(ExposureCalculator.formatShutterSpeed(speed))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)
                                            .frame(width: 55, alignment: .leading)

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.secondaryColor)
                                            .frame(width: 12)

                                        HStack(spacing: 2) {
                                            Text("1/")
                                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                                .foregroundStyle(theme.secondaryColor)
                                            TextField(
                                                reciprocalPlaceholder(for: speed),
                                                text: calibrationBinding(for: speed)
                                            )
                                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)
                                            .keyboardType(.numberPad)
                                            .frame(width: 50)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }

                        Text("Advanced: if you've measured a shutter speed to differ from its marking, enter the actual value. E.g. if 1/125 runs at 1/105, type 105.")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.secondaryColor)
                            .padding(.leading, 4)
                            .padding(.top, -18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(theme.backgroundColor)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                ZStack {
                    Text(isEditing ? "EDIT CAMERA" : "NEW CAMERA")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.primaryColor)

                    HStack {
                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.primaryColor)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(
                                    Capsule()
                                        .fill(theme.primaryColor.opacity(theme.subtleOpacity))
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button { save() } label: {
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.primaryColor)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(
                                    Capsule()
                                        .fill(theme.primaryColor.opacity(theme.subtleOpacity))
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1.0)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.backgroundColor)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [theme.backgroundColor, theme.backgroundColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 6)
                    .offset(y: 6)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { loadProfile() }
            .sheet(isPresented: $showAddLens) {
                if let profile {
                    LensEditorView(lens: nil, profile: profile)
                }
            }
            .sheet(item: $editingLens) { lens in
                if let profile {
                    LensEditorView(lens: lens, profile: profile)
                }
            }
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
    }

    // MARK: - Shutter Speed Grid

    private var shutterSpeedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(standardShutterSpeeds, id: \.self) { speed in
                Button {
                    toggleShutterSpeed(speed)
                } label: {
                    Text(ExposureCalculator.formatShutterSpeed(speed))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedShutterSpeeds.contains(speed)
                                ? theme.primaryColor.opacity(0.85)
                                : theme.primaryColor.opacity(0.06)
                        )
                        .foregroundStyle(selectedShutterSpeeds.contains(speed) ? theme.backgroundColor : theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func reciprocalPlaceholder(for speed: Double) -> String {
        if speed >= 1.0 {
            return speed == floor(speed) ? "\(Int(speed))\"" : String(format: "%.1f\"", speed)
        }
        return "\(Int(round(1.0 / speed)))"
    }

    private func calibrationBinding(for speed: Double) -> Binding<String> {
        Binding(
            get: { calibrationEntries[speed] ?? "" },
            set: { calibrationEntries[speed] = $0 }
        )
    }

    // MARK: - Section/Row Helpers (identical to SettingsView)

    private func sheetSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.secondaryColor)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(theme.subtleOpacity))
            )
        }
    }

    private struct PressableButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.4 : 1.0)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }

    private func sheetRow<Content: View>(isLast: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            if !isLast {
                Rectangle()
                    .fill(theme.primaryColor.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    // MARK: - Actions

    private func toggleShutterSpeed(_ speed: Double) {
        if selectedShutterSpeeds.contains(speed) {
            selectedShutterSpeeds.remove(speed)
        } else {
            selectedShutterSpeeds.insert(speed)
        }
    }

    private func loadProfile() {
        guard let profile else {
            // Set default shutter speeds for new profile
            selectedShutterSpeeds = Set(ExposureCalculator.standardShutterSpeeds.filter { speed in
                // Common mechanical camera speeds
                let reciprocal = 1.0 / speed
                return [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000].contains(Int(round(reciprocal)))
                    || speed >= 1.0
            })
            return
        }
        name = profile.name
        filmISO = profile.filmISO
        selectedShutterSpeeds = Set(profile.shutterSpeeds)
        compensation = profile.exposureCompensation
        // Load calibration: convert actual speeds back to reciprocal text
        for (nominal, actual) in profile.shutterCalibration {
            if actual >= 1.0 {
                calibrationEntries[nominal] = actual == floor(actual)
                    ? "\(Int(actual))"
                    : String(format: "%.1f", actual)
            } else {
                calibrationEntries[nominal] = "\(Int(round(1.0 / actual)))"
            }
        }
    }

    private func buildCalibration() -> [Double: Double] {
        var result: [Double: Double] = [:]
        for (nominal, text) in calibrationEntries {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let reciprocal = Double(trimmed), reciprocal > 0 else { continue }
            let actualSpeed = 1.0 / reciprocal
            // Only store if meaningfully different from nominal
            if abs(log2(actualSpeed) - log2(nominal)) > 0.01 {
                result[nominal] = actualSpeed
            }
        }
        return result
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let calibration = buildCalibration()

        if let profile {
            profile.name = trimmedName
            profile.filmISO = filmISO
            profile.shutterSpeeds = Array(selectedShutterSpeeds).sorted()
            profile.exposureCompensation = compensation
            profile.shutterCalibration = calibration
        } else {
            let newProfile = CameraProfile(
                name: trimmedName,
                shutterSpeeds: Array(selectedShutterSpeeds).sorted(),
                filmISO: filmISO,
                exposureCompensation: compensation,
                isSelected: false,
                shutterCalibration: calibration
            )
            modelContext.insert(newProfile)
        }
        dismiss()
    }
}
