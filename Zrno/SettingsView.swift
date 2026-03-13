import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section("Color Scheme") {
                    ForEach(ThemeScheme.allCases) { scheme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                theme.scheme = scheme
                            }
                        } label: {
                            HStack(spacing: 14) {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(scheme.backgroundColor)
                                    Rectangle()
                                        .fill(scheme.primaryColor)
                                }
                                .frame(width: 44, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.quaternary, lineWidth: 1)
                                )

                                Text(scheme.displayName)
                                    .font(.system(size: 17, weight: .regular, design: .rounded))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if theme.scheme == scheme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }

                Section("Font") {
                    ForEach(ThemeFontDesign.allCases) { fontDesign in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                theme.fontDesign = fontDesign
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text("f/2.8")
                                    .font(.system(size: 18, weight: .medium, design: fontDesign.swiftUIDesign))
                                    .foregroundStyle(.primary)
                                    .frame(width: 60, alignment: .leading)

                                Text(fontDesign.displayName)
                                    .font(.system(size: 17, weight: .regular, design: .rounded))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if theme.fontDesign == fontDesign {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Zrno")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                        Spacer()
                        Text("Light Meter for Film")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
        }
        .tint(.primary)
    }
}
