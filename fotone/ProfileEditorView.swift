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

                Section("Exposure Compensation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EV \(compensation >= 0 ? "+" : "")\(compensation, specifier: "%.1f")")
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                        Slider(value: $compensation, in: -3...3, step: 0.3) {
                            Text("Compensation")
                        }
                        Text("Adjust if your camera meters differently than expected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
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
                                ? Color.blue.opacity(0.8)
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(selectedApertures.contains(f) ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                ? Color.blue.opacity(0.8)
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(selectedShutterSpeeds.contains(speed) ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let profile {
            // Update existing
            profile.name = trimmedName
            profile.filmISO = filmISO
            profile.apertures = Array(selectedApertures).sorted()
            profile.shutterSpeeds = Array(selectedShutterSpeeds).sorted()
            profile.exposureCompensation = compensation
        } else {
            // Create new
            let newProfile = CameraProfile(
                name: trimmedName,
                apertures: Array(selectedApertures).sorted(),
                shutterSpeeds: Array(selectedShutterSpeeds).sorted(),
                filmISO: filmISO,
                exposureCompensation: compensation,
                isSelected: false
            )
            modelContext.insert(newProfile)
        }
        dismiss()
    }
}
