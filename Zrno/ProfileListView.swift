import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \CameraProfile.createdAt) private var profiles: [CameraProfile]
    @State private var showEditor = false
    @State private var editingProfile: CameraProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sheetSection("Cameras") {
                        ForEach(Array(profiles.enumerated()), id: \.element.persistentModelID) { index, profile in
                            sheetRow(isLast: index == profiles.count - 1) {
                                HStack {
                                    Button {
                                        selectProfile(profile)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(profile.name)
                                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(theme.primaryColor)
                                                Text("ISO \(profile.filmISO) · \(profile.sortedApertures.count) apertures · \(profile.sortedShutterSpeeds.count) speeds")
                                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                                    .foregroundStyle(theme.secondaryColor)
                                            }

                                            Spacer()

                                            if profile.isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(theme.primaryColor)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    HStack(spacing: 12) {
                                        Button {
                                            editingProfile = profile
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(theme.secondaryColor)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            modelContext.delete(profile)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(theme.secondaryColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
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
                    Text("CAMERAS")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.primaryColor)

                    HStack {
                        Button { dismiss() } label: {
                            Text("Done")
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

                        Spacer()

                        Button {
                            showEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(theme.primaryColor)
                                .frame(width: 36, height: 36)
                                .background(
                                    Capsule()
                                        .fill(theme.primaryColor.opacity(theme.subtleOpacity))
                                )
                        }
                        .buttonStyle(.plain)
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
            .sheet(isPresented: $showEditor) {
                ProfileEditorView(profile: nil)
                    .environment(\.appTheme, theme)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile)
                    .environment(\.appTheme, theme)
            }
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
    }

    private func selectProfile(_ profile: CameraProfile) {
        for p in profiles {
            p.isSelected = (p.persistentModelID == profile.persistentModelID)
        }
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
}
