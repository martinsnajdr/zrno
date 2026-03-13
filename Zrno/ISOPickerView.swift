import SwiftUI

struct ISOPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
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
                            .font(.system(size: 18, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.primaryColor)

                        Spacer()

                        if profile?.filmISO == iso {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.primaryColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .listRowBackground(theme.primaryColor.opacity(0.06))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                ZStack {
                    Text("FILM ISO")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.primaryColor)

                    HStack {
                        Spacer()
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
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
    }
}
