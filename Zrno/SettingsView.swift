import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection("Appearance") {
                        ForEach(AppearanceMode.allCases) { mode in
                            settingsRow(isLast: mode == AppearanceMode.allCases.last) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        theme.appearanceMode = mode
                                    }
                                } label: {
                                    HStack {
                                        Text(mode.displayName)
                                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)
                                        Spacer()
                                        if theme.appearanceMode == mode {
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

                    settingsSection("Color Scheme") {
                        ForEach(ThemeScheme.allCases) { scheme in
                            settingsRow(isLast: scheme == ThemeScheme.allCases.last) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        theme.scheme = scheme
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(scheme.backgroundColor(isDark: true))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .strokeBorder(scheme.primaryColor(isDark: true), lineWidth: 2)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(theme.primaryColor.opacity(0.1), lineWidth: 0.5)
                                            )

                                        Text(scheme.displayName)
                                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)

                                        Spacer()

                                        if theme.scheme == scheme {
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

                    settingsSection("Font") {
                        ForEach(ThemeFontDesign.allCases) { fontDesign in
                            settingsRow(isLast: fontDesign == ThemeFontDesign.allCases.last) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        theme.fontDesign = fontDesign
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Text("f/2.8")
                                            .font(.system(size: 16, weight: .medium, design: fontDesign.swiftUIDesign))
                                            .foregroundStyle(theme.primaryColor)
                                            .frame(width: 56, alignment: .leading)

                                        Text(fontDesign.displayName)
                                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)

                                        Spacer()

                                        if theme.fontDesign == fontDesign {
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

                    settingsSection("About") {
                        settingsRow(isLast: true) {
                            HStack {
                                Text("Zrno")
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(theme.primaryColor)
                                Spacer()
                                Text("Your best friend when nobody wants to go out with you to take amazing photos")
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundStyle(theme.secondaryColor)
                                    .multilineTextAlignment(.trailing)
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
                    Text("SETTINGS")
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

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func settingsRow<Content: View>(isLast: Bool = false, @ViewBuilder content: () -> Content) -> some View {
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

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}




