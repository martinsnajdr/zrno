import SwiftUI
import SwiftData

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: CameraProfile?

    @State private var name: String = ""
    @State private var filmISO: Int = 400
    @State private var selectedApertures: Set<Double> = [2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
    @State private var selectedShutterSpeeds: Set<Double> = []
    @State private var compensation: Double = 0.0
    @State private var calibrationEntries: [Double: String] = [:] // nominal speed → actual reciprocal text

    private let standardApertures: [Double] = ExposureCalculator.standardApertures
    private let standardShutterSpeeds: [Double] = ExposureCalculator.standardShutterSpeeds

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera Name") {
                    TextField("e.g. Leica M6", text: $name)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                }

                Section("Film ISO") {
                    Picker("ISO", selection: $filmISO) {
                        ForEach(ExposureCalculator.standardISOs, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    apertureGrid
                } header: {
                    Text("Available Apertures")
                } footer: {
                    Text("Tap to toggle. Select the f-stops your lens has.")
                }

                Section {
                    shutterSpeedGrid
                } header: {
                    Text("Available Shutter Speeds")
                } footer: {
                    Text("Select the shutter speeds your camera supports.")
                }

                if !selectedShutterSpeeds.isEmpty {
                    Section {
                        calibrationList
                    } header: {
                        Text("Speed Calibration")
                    } footer: {
                        Text("If a shutter speed differs from its marking, enter the actual measured value. E.g. if 1/125 actually exposes at 1/105, type 105.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Camera" : "New Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 17, weight: .semibold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadProfile() }
        }
        .tint(.primary)
    }

    // MARK: - Aperture Grid

    private var apertureGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(standardApertures, id: \.self) { f in
                Button {
                    toggleAperture(f)
                } label: {
                    Text(ExposureCalculator.formatAperture(f))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedApertures.contains(f)
                                ? Color.primary.opacity(0.85)
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(selectedApertures.contains(f) ? Color(.systemBackground) : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
                                ? Color.primary.opacity(0.85)
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(selectedShutterSpeeds.contains(speed) ? Color(.systemBackground) : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Calibration List

    private var calibrationList: some View {
        ForEach(Array(selectedShutterSpeeds).sorted(), id: \.self) { speed in
            HStack {
                Text(ExposureCalculator.formatShutterSpeed(speed))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .frame(width: 70, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    Text("1/")
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField(
                        reciprocalPlaceholder(for: speed),
                        text: calibrationBinding(for: speed)
                    )
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                }
            }
        }
    }

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

    // MARK: - Actions

    private func toggleAperture(_ f: Double) {
        if selectedApertures.contains(f) {
            selectedApertures.remove(f)
        } else {
            selectedApertures.insert(f)
        }
    }

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
        selectedApertures = Set(profile.apertures)
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
            profile.apertures = Array(selectedApertures).sorted()
            profile.shutterSpeeds = Array(selectedShutterSpeeds).sorted()
            profile.exposureCompensation = compensation
            profile.shutterCalibration = calibration
        } else {
            let newProfile = CameraProfile(
                name: trimmedName,
                apertures: Array(selectedApertures).sorted(),
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
