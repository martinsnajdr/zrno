import SwiftUI
import SwiftData

struct LensEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let lens: Lens?
    let profile: CameraProfile

    @State private var name: String = ""
    @State private var focalLength: String = ""
    @State private var selectedApertures: Set<Double> = [2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0]

    private let standardApertures: [Double] = ExposureCalculator.standardApertures

    private var isEditing: Bool { lens != nil }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("e.g. Summicron 50mm f/2", text: $name)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.primaryColor)
                        .listRowBackground(theme.primaryColor.opacity(0.06))
                } header: {
                    Text("Lens Name")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }

                Section {
                    TextField("e.g. 50", text: $focalLength)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.primaryColor)
                        .keyboardType(.numberPad)
                        .listRowBackground(theme.primaryColor.opacity(0.06))
                } header: {
                    Text("Focal Length (mm)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }

                Section {
                    apertureGrid
                        .listRowBackground(theme.primaryColor.opacity(0.06))
                } header: {
                    Text("Available Apertures")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                } footer: {
                    Text("Tap to toggle. Select the f-stops this lens has.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.secondaryColor)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                ZStack {
                    Text(isEditing ? "EDIT LENS" : "NEW LENS")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.primaryColor)

                    HStack {
                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .regular, design: .monospaced))
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
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.primaryColor)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(
                                    Capsule()
                                        .fill(theme.primaryColor.opacity(theme.subtleOpacity))
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity((name.trimmingCharacters(in: .whitespaces).isEmpty || focalLength.isEmpty) ? 0.3 : 1.0)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || focalLength.isEmpty)
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
                    .frame(height: 16)
                    .offset(y: 16)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { loadLens() }
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
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
                                ? theme.primaryColor.opacity(0.85)
                                : theme.primaryColor.opacity(0.06)
                        )
                        .foregroundStyle(selectedApertures.contains(f) ? theme.backgroundColor : theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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

    private func loadLens() {
        guard let lens else { return }
        name = lens.name
        focalLength = "\(lens.focalLength)"
        selectedApertures = Set(lens.apertures)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let mm = Int(focalLength) ?? 50

        if let lens {
            lens.name = trimmedName
            lens.focalLength = mm
            lens.apertures = Array(selectedApertures).sorted()
        } else {
            let newLens = Lens(
                name: trimmedName,
                focalLength: mm,
                apertures: Array(selectedApertures).sorted(),
                isSelected: profile.lenses.isEmpty
            )
            newLens.cameraProfile = profile
            modelContext.insert(newLens)
        }
        dismiss()
    }
}
