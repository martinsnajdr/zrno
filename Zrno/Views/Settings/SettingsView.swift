import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @AppStorage("zrno.funMode") private var funMode = false

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
                                            .fill(scheme.primaryColor(isDark: theme.effectiveIsDark))
                                            .frame(width: 24, height: 24)

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
                        settingsRow(isLast: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ZRNO")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(theme.primaryColor)
                                    .tracking(4)
                                Text("Your best friend when nobody wants to go out with you to take photos.")
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(theme.secondaryColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        settingsRow(isLast: false) {
                            Button {
                                if let url = URL(string: "https://instagram.com/martinsnajdr") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("@martinsnajdr")
                                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(theme.primaryColor)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.secondaryColor)
                                    }
                                    Text("If you enjoy the app, please give me a follow and send a photo of you using it. I'd love to feature it in an Instagram story.")
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundStyle(theme.secondaryColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        settingsRow(isLast: false) {
                            NavigationLink {
                                DocumentationView()
                            } label: {
                                HStack {
                                    Text("Guide")
                                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                                        .foregroundStyle(theme.primaryColor)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(theme.secondaryColor)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        settingsRow(isLast: !funMode) {
                            HStack {
                                Text("Fun Mode")
                                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                                    .foregroundStyle(theme.primaryColor)
                                Spacer()
                                Toggle("", isOn: $funMode)
                                    .labelsHidden()
                                    .toggleStyle(ThemeToggleStyle(theme: theme))
                            }
                        }
                        if funMode {
                            settingsRow(isLast: true) {
                                highScoresRow
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

    private var highScoresRow: some View {
        let zrnoidHigh = UserDefaults.standard.integer(forKey: ArkanoidGame.highScoreKey)
        let zrnorunHigh = UserDefaults.standard.integer(forKey: RunnerGame.highScoreKey)
        return VStack(alignment: .leading, spacing: 6) {
            Text("High Scores")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.primaryColor)
            HStack(spacing: 4) {
                Text("Zrnoid")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
                Spacer()
                Text("\(zrnoidHigh)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.primaryColor)
            }
            HStack(spacing: 4) {
                Text("Zrnorun")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryColor)
                Spacer()
                Text("\(zrnorunHigh)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.primaryColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ThemeToggleStyle: ToggleStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        HStack {
            configuration.label
            RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? theme.primaryColor : theme.primaryColor.opacity(theme.subtleOpacity * 2))
                .frame(width: 44, height: 26)
                .overlay(
                    Circle()
                        .fill(theme.backgroundColor)
                        .frame(width: 22, height: 22)
                        .offset(x: isOn ? 9 : -9)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}




