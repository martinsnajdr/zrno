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
            List {
                ForEach(profiles) { profile in
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
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(theme.primaryColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(theme.primaryColor.opacity(0.06))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(profile)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            editingProfile = profile
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
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
}
