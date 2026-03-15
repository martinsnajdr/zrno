import SwiftUI

struct ISOPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let profile: CameraProfile?

    private let isoValues = ExposureCalculator.standardISOs

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sheetSection("Film ISO") {
                        ForEach(Array(isoValues.enumerated()), id: \.element) { index, iso in
                            sheetRow(isLast: index == isoValues.count - 1) {
                                Button {
                                    profile?.filmISO = iso
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text("ISO \(iso, format: .number.grouping(.never))")
                                            .font(.system(size: 15, weight: .regular, design: .monospaced))
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
                                .buttonStyle(.plain)
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
                    Text("FILM ISO")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(theme.primaryColor)

                    HStack {
                        Spacer()
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
        }
        .tint(theme.primaryColor)
        .presentationCornerRadius(16)
        .presentationBackground(theme.backgroundColor)
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
