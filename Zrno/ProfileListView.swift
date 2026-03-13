import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("ISO \(profile.filmISO) · \(profile.sortedApertures.count) apertures · \(profile.sortedShutterSpeeds.count) speeds")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if profile.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
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
            .navigationTitle("Cameras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                ProfileEditorView(profile: nil)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile)
            }
        }
        .tint(.primary)
    }

    private func selectProfile(_ profile: CameraProfile) {
        for p in profiles {
            p.isSelected = (p.persistentModelID == profile.persistentModelID)
        }
    }
}
