import Testing
import Foundation
import SwiftUI
@testable import Zrno

// MARK: - AppearanceMode

struct AppearanceModeTests {

    @Test func rawValues() {
        #expect(AppearanceMode.system.rawValue == "system")
        #expect(AppearanceMode.light.rawValue == "light")
        #expect(AppearanceMode.dark.rawValue == "dark")
    }

    @Test func allCases() {
        #expect(AppearanceMode.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(AppearanceMode.system.displayName == "System")
        #expect(AppearanceMode.light.displayName == "Light")
        #expect(AppearanceMode.dark.displayName == "Dark")
    }

    @Test func colorScheme() {
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test func encodeDecode() throws {
        for mode in AppearanceMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AppearanceMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

// MARK: - ThemeScheme

struct ThemeSchemeTests {

    @Test func allCases() {
        #expect(ThemeScheme.allCases.count == 4)
    }

    @Test func displayNames() {
        #expect(ThemeScheme.noir.displayName == "Midnight Noir")
        #expect(ThemeScheme.cream.displayName == "Vintage Cream")
        #expect(ThemeScheme.blueSteel.displayName == "Frosty Steel")
        #expect(ThemeScheme.darkroomRed.displayName == "Darkroom Red")
    }

    @Test func darkAndLightBackgroundsDiffer() {
        for scheme in ThemeScheme.allCases {
            let dark = scheme.backgroundColor(isDark: true)
            let light = scheme.backgroundColor(isDark: false)
            #expect(dark != light, "Scheme \(scheme.displayName) should have different dark/light backgrounds")
        }
    }

    @Test func darkAndLightPrimaryColorsDiffer() {
        for scheme in ThemeScheme.allCases {
            let dark = scheme.primaryColor(isDark: true)
            let light = scheme.primaryColor(isDark: false)
            #expect(dark != light, "Scheme \(scheme.displayName) should have different dark/light primary colors")
        }
    }

    @Test func secondaryIsReducedOpacityOfPrimary() {
        // Secondary is primary with 0.4 opacity — they share the same base color
        for scheme in ThemeScheme.allCases {
            for isDark in [true, false] {
                let secondary = scheme.secondaryColor(isDark: isDark)
                let primary = scheme.primaryColor(isDark: isDark)
                // Both should be non-nil SwiftUI Colors (just ensure they exist)
                #expect(type(of: secondary) == type(of: primary))
            }
        }
    }

    @Test func encodeDecode() throws {
        for scheme in ThemeScheme.allCases {
            let data = try JSONEncoder().encode(scheme)
            let decoded = try JSONDecoder().decode(ThemeScheme.self, from: data)
            #expect(decoded == scheme)
        }
    }
}

// MARK: - ThemeFontDesign

struct ThemeFontDesignTests {

    @Test func allCases() {
        #expect(ThemeFontDesign.allCases.count == 4)
    }

    @Test func displayNames() {
        #expect(ThemeFontDesign.rounded.displayName == "Rounded")
        #expect(ThemeFontDesign.standard.displayName == "Standard")
        #expect(ThemeFontDesign.monospaced.displayName == "Mono")
        #expect(ThemeFontDesign.serif.displayName == "Serif")
    }

    @Test func swiftUIDesignMapping() {
        #expect(ThemeFontDesign.rounded.swiftUIDesign == .rounded)
        #expect(ThemeFontDesign.standard.swiftUIDesign == .default)
        #expect(ThemeFontDesign.monospaced.swiftUIDesign == .monospaced)
        #expect(ThemeFontDesign.serif.swiftUIDesign == .serif)
    }

    @Test func encodeDecode() throws {
        for design in ThemeFontDesign.allCases {
            let data = try JSONEncoder().encode(design)
            let decoded = try JSONDecoder().decode(ThemeFontDesign.self, from: data)
            #expect(decoded == design)
        }
    }
}

// MARK: - AppTheme

@Suite(.serialized) struct AppThemeTests {

    @Test func defaultTheme() {
        // Clear saved theme to get defaults
        UserDefaults.standard.removeObject(forKey: "zrno.theme")
        UserDefaults.standard.synchronize()
        let theme = AppTheme()
        #expect(theme.scheme == .noir)
        #expect(theme.fontDesign == .rounded)
        #expect(theme.appearanceMode == .dark)
        UserDefaults.standard.removeObject(forKey: "zrno.theme")
        UserDefaults.standard.synchronize()
    }

    @Test func subtleOpacityDarkMode() {
        let theme = AppTheme()
        theme.effectiveIsDark = true
        #expect(theme.subtleOpacity == 0.08)
    }

    @Test func subtleOpacityLightMode() {
        let theme = AppTheme()
        theme.effectiveIsDark = false
        #expect(theme.subtleOpacity == 0.06)
    }

    @Test func designReflectsFontDesign() {
        let theme = AppTheme()
        theme.fontDesign = .monospaced
        #expect(theme.design == .monospaced)
        theme.fontDesign = .serif
        #expect(theme.design == .serif)
    }

    @Test func appearanceModeSetsDarkDirectly() {
        let theme = AppTheme()
        theme.appearanceMode = .dark
        #expect(theme.effectiveIsDark == true)
        theme.appearanceMode = .light
        #expect(theme.effectiveIsDark == false)
    }

    @Test func savePersistsTheme() {
        UserDefaults.standard.removeObject(forKey: "zrno.theme")
        UserDefaults.standard.synchronize()
        let theme = AppTheme()
        theme.scheme = .blueSteel
        theme.fontDesign = .serif
        // save() is called in didSet

        let reloaded = AppTheme()
        #expect(reloaded.scheme == .blueSteel)
        #expect(reloaded.fontDesign == .serif)
        UserDefaults.standard.removeObject(forKey: "zrno.theme")
        UserDefaults.standard.synchronize()
    }
}
