import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query private var profiles: [CameraProfile]
    @State private var showEditor = false

    /// Custom profiles sorted by name, with the default "Basic" profile always last.
    private var sortedProfiles: [CameraProfile] {
        let custom = profiles.filter { !$0.isDefault }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let defaults = profiles.filter { $0.isDefault }
        return custom + defaults
    }
    @State private var editingProfile: CameraProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sheetSection("Cameras") {
                        ForEach(Array(sortedProfiles.enumerated()), id: \.element.persistentModelID) { index, profile in
                            sheetRow(isLast: index == sortedProfiles.count - 1) {
                                HStack(spacing: 12) {
                                    // Checkmark circle
                                    Button {
                                        selectProfile(profile)
                                    } label: {
                                        Image(systemName: profile.isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(profile.isSelected ? theme.primaryColor : theme.secondaryColor.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)

                                    // Name + info (tappable to select)
                                    Button {
                                        selectProfile(profile)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(profile.name)
                                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                                .foregroundStyle(theme.primaryColor)
                                            Text(profileSubtitle(profile))
                                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                                .foregroundStyle(theme.secondaryColor)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    // Edit + Delete (hidden for default profile)
                                    if !profile.isDefault {
                                        Button {
                                            editingProfile = profile
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
                                        Button {
                                            modelContext.delete(profile)
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
                    .frame(height: 6)
                    .offset(y: 6)
                    .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showEditor) {
                ProfileEditorView(profile: nil, isNew: true)
                    .environment(\.appTheme, theme)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile, isNew: false)
                    .environment(\.appTheme, theme)
            }
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
    }

    private func profileSubtitle(_ profile: CameraProfile) -> String {
        if profile.isDefault {
            return "Default light meter"
        }
        if profile.type == .pinhole {
            return "Pinhole f/\(Int(round(profile.effectivePinholeAperture)))"
        }
        return "\(profile.lenses.count) lenses · \(profile.sortedShutterSpeeds.count) speeds"
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
}
