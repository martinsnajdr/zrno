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
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    // Lens Name
                    sheetSection("Lens Name") {
                        sheetRow(isLast: true) {
                            PlainTextField(
                                placeholder: "e.g. Summicron 50mm f/2",
                                text: $name,
                                textColor: UIColor(theme.primaryColor),
                                placeholderColor: UIColor(theme.secondaryColor.opacity(0.5))
                            )
                        }
                    }

                    // Focal Length
                    sheetSection("Focal Length (mm)") {
                        sheetRow(isLast: true) {
                            PlainTextField(
                                placeholder: "e.g. 50",
                                text: $focalLength,
                                textColor: UIColor(theme.primaryColor),
                                placeholderColor: UIColor(theme.secondaryColor.opacity(0.5)),
                                keyboardType: .numberPad
                            )
                        }
                    }

                    // Apertures
                    sheetSection("Available Apertures") {
                        sheetRow(isLast: true) {
                            apertureGrid
                        }
                    }

                    sectionFooter("Tap to toggle. Select the f-stops this lens has.")
                }
                .padding(.horizontal, 16)
                .padding(.top, 64)
                .padding(.bottom, 32)
            }

            // Floating top bar
            ZStack {
                Text("LENS")
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
                    .opacity((name.trimmingCharacters(in: .whitespaces).isEmpty || focalLength.isEmpty) ? 0.3 : 1.0)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || focalLength.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
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
        .background(theme.backgroundColor)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear { loadLens() }
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

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.secondaryColor)
            .padding(.leading, 4)
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
