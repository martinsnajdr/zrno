import SwiftUI

// MARK: - Theme Scheme

enum ThemeScheme: String, CaseIterable, Codable, Identifiable {
    case noir
    case cream
    case blueSteel
    case darkroomRed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noir: return "Noir"
        case .cream: return "Cream"
        case .blueSteel: return "Blue Steel"
        case .darkroomRed: return "Darkroom Red"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .noir: return .black
        case .cream: return Color(red: 0.10, green: 0.10, blue: 0.09)
        case .blueSteel: return Color(red: 0.04, green: 0.05, blue: 0.08)
        case .darkroomRed: return Color(red: 0.06, green: 0.04, blue: 0.04)
        }
    }

    var primaryColor: Color {
        switch self {
        case .noir: return .white
        case .cream: return Color(red: 0.96, green: 0.94, blue: 0.91)
        case .blueSteel: return Color(red: 0.72, green: 0.77, blue: 0.83)
        case .darkroomRed: return Color(red: 0.77, green: 0.25, blue: 0.25)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .noir: return .white.opacity(0.4)
        case .cream: return Color(red: 0.96, green: 0.94, blue: 0.91).opacity(0.4)
        case .blueSteel: return Color(red: 0.72, green: 0.77, blue: 0.83).opacity(0.4)
        case .darkroomRed: return Color(red: 0.77, green: 0.25, blue: 0.25).opacity(0.4)
        }
    }

    var accentColor: Color {
        switch self {
        case .noir: return .white.opacity(0.7)
        case .cream: return Color(red: 0.96, green: 0.94, blue: 0.91).opacity(0.7)
        case .blueSteel: return Color(red: 0.72, green: 0.77, blue: 0.83).opacity(0.7)
        case .darkroomRed: return Color(red: 0.77, green: 0.25, blue: 0.25).opacity(0.7)
        }
    }

    /// Tint color for the monochrome camera preview CIFilter
    var previewTint: (r: Double, g: Double, b: Double) {
        switch self {
        case .noir: return (0.9, 0.9, 0.85)
        case .cream: return (0.95, 0.92, 0.82)
        case .blueSteel: return (0.75, 0.80, 0.90)
        case .darkroomRed: return (0.85, 0.55, 0.55)
        }
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

    // Convenience accessors
    var backgroundColor: Color { scheme.backgroundColor }
    var primaryColor: Color { scheme.primaryColor }
    var secondaryColor: Color { scheme.secondaryColor }
    var accentColor: Color { scheme.accentColor }
    var design: Font.Design { fontDesign.swiftUIDesign }

    init() {
        if let data = UserDefaults.standard.data(forKey: "zrno.theme"),
           let saved = try? JSONDecoder().decode(ThemeData.self, from: data) {
            self.scheme = saved.scheme
            self.fontDesign = saved.fontDesign
        } else {
            self.scheme = .noir
            self.fontDesign = .rounded
        }
    }

    private func save() {
        let data = ThemeData(scheme: scheme, fontDesign: fontDesign)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "zrno.theme")
        }
    }
}

private struct ThemeData: Codable {
    let scheme: ThemeScheme
    let fontDesign: ThemeFontDesign
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
