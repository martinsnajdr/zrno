import SwiftUI

struct ISOPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: CameraProfile?

    private let isoValues = ExposureCalculator.standardISOs

    var body: some View {
        NavigationStack {
            List(isoValues, id: \.self) { iso in
                Button {
                    profile?.filmISO = iso
                    dismiss()
                } label: {
                    HStack {
                        Text("ISO \(iso)")
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(.primary)

                        Spacer()

                        if profile?.filmISO == iso {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .listRowBackground(Color(.systemGroupedBackground))
            }
            .navigationTitle("Film ISO")
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
