import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Scheme

enum ThemeScheme: String, CaseIterable, Codable, Identifiable {
    case noir
    case cream
    case blueSteel
    case darkroomRed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noir: return "Midnight Noir"
        case .cream: return "Vintage Cream"
        case .blueSteel: return "Frosty Steel"
        case .darkroomRed: return "Darkroom Red"
        }
    }

    func backgroundColor(isDark: Bool) -> Color {
        switch (self, isDark) {
        case (.noir, true):        return .black
        case (.noir, false):       return Color(red: 0.96, green: 0.96, blue: 0.95)
        case (.cream, true):       return Color(red: 0.10, green: 0.10, blue: 0.09)
        case (.cream, false):      return Color(red: 0.96, green: 0.94, blue: 0.90)
        case (.blueSteel, true):   return Color(red: 0.04, green: 0.05, blue: 0.08)
        case (.blueSteel, false):  return Color(red: 0.92, green: 0.94, blue: 0.97)
        case (.darkroomRed, true): return Color(red: 0.06, green: 0.04, blue: 0.04)
        case (.darkroomRed, false):return Color(red: 0.97, green: 0.94, blue: 0.94)
        }
    }

    func primaryColor(isDark: Bool) -> Color {
        switch (self, isDark) {
        case (.noir, true):        return .white
        case (.noir, false):       return Color(red: 0.08, green: 0.08, blue: 0.08)
        case (.cream, true):       return Color(red: 0.96, green: 0.94, blue: 0.91)
        case (.cream, false):      return Color(red: 0.20, green: 0.18, blue: 0.15)
        case (.blueSteel, true):   return Color(red: 0.72, green: 0.77, blue: 0.83)
        case (.blueSteel, false):  return Color(red: 0.15, green: 0.20, blue: 0.30)
        case (.darkroomRed, true): return Color(red: 0.77, green: 0.25, blue: 0.25)
        case (.darkroomRed, false):return Color(red: 0.65, green: 0.15, blue: 0.15)
        }
    }

    func secondaryColor(isDark: Bool) -> Color {
        primaryColor(isDark: isDark).opacity(0.4)
    }

    func accentColor(isDark: Bool) -> Color {
        primaryColor(isDark: isDark).opacity(0.7)
    }

}

// MARK: - Font Design

enum ThemeFontDesign: String, CaseIterable, Codable, Identifiable {
    case rounded
    case standard
    case monospaced
    case serif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded: return "Rounded"
        case .standard: return "Standard"
        case .monospaced: return "Mono"
        case .serif: return "Serif"
        }
    }

    var swiftUIDesign: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .standard: return .default
        case .monospaced: return .monospaced
        case .serif: return .serif
        }
    }
}

// MARK: - App Theme

@Observable
final class AppTheme {
    var scheme: ThemeScheme {
        didSet { save() }
    }
    var fontDesign: ThemeFontDesign {
        didSet { save() }
    }
    var appearanceMode: AppearanceMode {
        didSet {
            // Update effectiveIsDark immediately so UI responds without waiting
            switch appearanceMode {
            case .dark: effectiveIsDark = true
            case .light: effectiveIsDark = false
            case .system: break // system stays as-is until colorScheme reports
            }
            save()
        }
    }

    /// Updated by the view layer based on the effective color scheme.
    var effectiveIsDark: Bool = true

    // Convenience accessors
    var backgroundColor: Color { scheme.backgroundColor(isDark: effectiveIsDark) }
    var primaryColor: Color { scheme.primaryColor(isDark: effectiveIsDark) }
    var secondaryColor: Color { scheme.secondaryColor(isDark: effectiveIsDark) }
    var accentColor: Color { scheme.accentColor(isDark: effectiveIsDark) }
    var design: Font.Design { fontDesign.swiftUIDesign }
    /// Subtle background opacity — 0.06 in light mode, 0.08 in dark mode for visibility
    var subtleOpacity: Double { effectiveIsDark ? 0.08 : 0.06 }

    init() {
        if let data = UserDefaults.standard.data(forKey: "zrno.theme"),
           let saved = try? JSONDecoder().decode(ThemeData.self, from: data) {
            self.scheme = saved.scheme
            self.fontDesign = saved.fontDesign
            self.appearanceMode = saved.appearanceMode ?? .dark
            self.effectiveIsDark = (saved.appearanceMode ?? .dark) != .light
        } else {
            self.scheme = .noir
            self.fontDesign = .rounded
            self.appearanceMode = .dark
        }
    }

    private func save() {
        let data = ThemeData(scheme: scheme, fontDesign: fontDesign, appearanceMode: appearanceMode)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "zrno.theme")
        }
    }
}

private struct ThemeData: Codable {
    let scheme: ThemeScheme
    let fontDesign: ThemeFontDesign
    let appearanceMode: AppearanceMode?
}

// MARK: - Environment Key

struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme()
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
