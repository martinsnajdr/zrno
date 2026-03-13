import Testing
import Foundation
@testable import fotone

// MARK: - ExposureCalculator Tests

struct ExposureCalculatorEVTests {

    @Test func ev100SunnyDay() {
        // Sunny 16 rule: f/16, 1/100s, ISO 100 → EV ~13.3
        let ev = ExposureCalculator.calculateEV100(aperture: 16.0, shutterSpeed: 1.0 / 100, iso: 100)
        #expect(abs(ev - 13.29) < 0.1)
    }

    @Test func ev100IndoorRoom() {
        // Typical indoor: f/2.8, 1/30s, ISO 400 → EV ~7
        let ev = ExposureCalculator.calculateEV100(aperture: 2.8, shutterSpeed: 1.0 / 30, iso: 400)
        #expect(abs(ev - 7.2) < 0.2)
    }

    @Test func ev100AtISO100() {
        // f/8, 1/125s at ISO 100: EV = log2(64 * 125) = log2(8000) ≈ 12.97
        let ev = ExposureCalculator.calculateEV100(aperture: 8.0, shutterSpeed: 1.0 / 125, iso: 100)
        #expect(abs(ev - 12.97) < 0.1)
    }

    @Test func ev100ISOAdjustment() {
        // Same scene, ISO 400 vs ISO 100 should differ by 2 stops
        let ev100 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 100)
        let ev400 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 400)
        #expect(abs((ev100 - ev400) - 2.0) < 0.01)
    }

    @Test func ev100ZeroGuards() {
        #expect(ExposureCalculator.calculateEV100(aperture: 0, shutterSpeed: 1.0 / 125, iso: 100) == 0)
        #expect(ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 0, iso: 100) == 0)
        #expect(ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 0) == 0)
    }

    @Test func ev100Reciprocity() {
        // Doubling ISO should be the same as opening one stop or halving shutter
        let ev1 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 200)
        let ev2 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 250, iso: 100)
        // These should be approximately equal (same light, same exposure)
        #expect(abs(ev1 - ev2) < 0.05)
    }
}

struct ExposureCalculatorSolvingTests {

    @Test func shutterSpeedForAperture() {
        // At EV100=13, ISO 100, f/16: shutter ≈ 1/100 (Sunny 16)
        let shutter = ExposureCalculator.shutterSpeed(forAperture: 16.0, ev100: 13.0, filmISO: 100)
        let reciprocal = 1.0 / shutter
        // Should be near 1/125 range
        #expect(reciprocal > 60 && reciprocal < 160)
    }

    @Test func apertureForShutterSpeed() {
        // At EV100=13, ISO 100, 1/125s: aperture ≈ f/16
        let aperture = ExposureCalculator.aperture(forShutterSpeed: 1.0 / 125, ev100: 13.0, filmISO: 100)
        #expect(abs(aperture - 16.0) < 2.0)
    }

    @Test func roundTrip() {
        // Solve for shutter, then solve back for aperture — should match
        let originalAperture = 5.6
        let ev100 = 12.0
        let iso = 400
        let shutter = ExposureCalculator.shutterSpeed(forAperture: originalAperture, ev100: ev100, filmISO: iso)
        let recoveredAperture = ExposureCalculator.aperture(forShutterSpeed: shutter, ev100: ev100, filmISO: iso)
        #expect(abs(recoveredAperture - originalAperture) < 0.01)
    }

    @Test func apertureForZeroShutter() {
        let result = ExposureCalculator.aperture(forShutterSpeed: 0, ev100: 12.0, filmISO: 100)
        #expect(result == 0)
    }

    @Test func higherISOFasterShutter() {
        let shutter100 = ExposureCalculator.shutterSpeed(forAperture: 5.6, ev100: 12.0, filmISO: 100)
        let shutter400 = ExposureCalculator.shutterSpeed(forAperture: 5.6, ev100: 12.0, filmISO: 400)
        // Higher ISO → faster shutter (smaller number)
        #expect(shutter400 < shutter100)
    }
}

struct ExposureCalculatorBestExposureTests {

    @Test func bestExposureFindsMatch() {
        let apertures = [2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
        let shutterSpeeds = [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let result = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )
        #expect(apertures.contains(result.aperture))
        #expect(shutterSpeeds.contains(result.shutterSpeed))
    }

    @Test func bestExposureWithCompensation() {
        let apertures = [2.8, 4.0, 5.6, 8.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: 0
        )
        let overexposed = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: 1.0
        )
        // +1 EV compensation should result in faster shutter or smaller aperture
        let normalEV = log2(normal.aperture * normal.aperture / normal.shutterSpeed)
        let overEV = log2(overexposed.aperture * overexposed.aperture / overexposed.shutterSpeed)
        #expect(overEV >= normalEV - 0.1) // Should be same or higher
    }

    @Test func allCombinationsReturnsValidPairs() {
        let apertures = [2.8, 4.0, 5.6, 8.0, 11.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let combos = ExposureCalculator.allCombinations(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )
        #expect(!combos.isEmpty)
        for combo in combos {
            #expect(apertures.contains(combo.aperture))
            #expect(shutterSpeeds.contains(combo.shutterSpeed))
        }
    }

    @Test func allCombinationsFiltersBadMatches() {
        // Very dim scene — only large apertures should match available fast shutters
        let apertures = [2.8, 16.0]
        let shutterSpeeds = [1.0/60, 1.0/30]
        let combos = ExposureCalculator.allCombinations(
            ev100: 15.0, filmISO: 100,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )
        // f/16 at EV15 ISO100 needs 1/125 which isn't available → might be filtered
        // f/2.8 at EV15 ISO100 needs ~1/12800 which is way off → should be filtered
        // The point is the filter works — we shouldn't get impossibly wrong combos
        for combo in combos {
            let idealShutter = ExposureCalculator.shutterSpeed(
                forAperture: combo.aperture, ev100: 15.0, filmISO: 100
            )
            let error = abs(log2(combo.shutterSpeed) - log2(idealShutter))
            #expect(error < 0.67) // Within 2/3 stop
        }
    }
}

struct ExposureCalculatorFormattingTests {

    @Test func formatShutterSpeedFractions() {
        #expect(ExposureCalculator.formatShutterSpeed(1.0 / 125) == "1/125")
        #expect(ExposureCalculator.formatShutterSpeed(1.0 / 60) == "1/60")
        #expect(ExposureCalculator.formatShutterSpeed(1.0 / 1000) == "1/1000")
        #expect(ExposureCalculator.formatShutterSpeed(1.0 / 250) == "1/250")
    }

    @Test func formatShutterSpeedWholeSeconds() {
        #expect(ExposureCalculator.formatShutterSpeed(1.0) == "1\u{2033}")
        #expect(ExposureCalculator.formatShutterSpeed(2.0) == "2\u{2033}")
        #expect(ExposureCalculator.formatShutterSpeed(8.0) == "8\u{2033}")
    }

    @Test func formatShutterSpeedFractionalSeconds() {
        let result = ExposureCalculator.formatShutterSpeed(1.5)
        #expect(result == "1.5\u{2033}")
    }

    @Test func formatShutterSpeedEdgeCases() {
        #expect(ExposureCalculator.formatShutterSpeed(0) == "—")
        #expect(ExposureCalculator.formatShutterSpeed(-1) == "—")
        #expect(ExposureCalculator.formatShutterSpeed(.infinity) == "—")
        #expect(ExposureCalculator.formatShutterSpeed(.nan) == "—")
    }

    @Test func formatApertureWholeNumbers() {
        #expect(ExposureCalculator.formatAperture(8.0) == "f/8")
        #expect(ExposureCalculator.formatAperture(16.0) == "f/16")
        #expect(ExposureCalculator.formatAperture(1.0) == "f/1")
    }

    @Test func formatApertureFractions() {
        #expect(ExposureCalculator.formatAperture(2.8) == "f/2.8")
        #expect(ExposureCalculator.formatAperture(5.6) == "f/5.6")
        #expect(ExposureCalculator.formatAperture(1.4) == "f/1.4")
    }

    @Test func formatApertureEdgeCases() {
        #expect(ExposureCalculator.formatAperture(0) == "—")
        #expect(ExposureCalculator.formatAperture(-1) == "—")
        #expect(ExposureCalculator.formatAperture(.infinity) == "—")
    }

    @Test func formatEVNormal() {
        #expect(ExposureCalculator.formatEV(12.3) == "12.3")
        #expect(ExposureCalculator.formatEV(0.0) == "0.0")
        #expect(ExposureCalculator.formatEV(-2.5) == "-2.5")
    }

    @Test func formatEVEdgeCases() {
        #expect(ExposureCalculator.formatEV(.nan) == "—")
        #expect(ExposureCalculator.formatEV(.infinity) == "—")
    }
}

// MARK: - CameraProfile Tests

struct CameraProfileTests {

    @Test func defaultValues() {
        let profile = CameraProfile(name: "Test Camera")
        #expect(profile.name == "Test Camera")
        #expect(profile.filmISO == 400)
        #expect(profile.exposureCompensation == 0.0)
        #expect(profile.isSelected == false)
        #expect(!profile.apertures.isEmpty)
        #expect(!profile.shutterSpeeds.isEmpty)
    }

    @Test func customValues() {
        let profile = CameraProfile(
            name: "Leica M6",
            apertures: [2.0, 2.8, 4.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125],
            filmISO: 100,
            exposureCompensation: -0.5,
            isSelected: true
        )
        #expect(profile.name == "Leica M6")
        #expect(profile.filmISO == 100)
        #expect(profile.exposureCompensation == -0.5)
        #expect(profile.isSelected == true)
        #expect(profile.apertures.count == 3)
        #expect(profile.shutterSpeeds.count == 3)
    }

    @Test func sortedApertures() {
        let profile = CameraProfile(
            name: "Test",
            apertures: [8.0, 2.8, 16.0, 1.4, 5.6]
        )
        let sorted = profile.sortedApertures
        #expect(sorted == [1.4, 2.8, 5.6, 8.0, 16.0])
    }

    @Test func sortedShutterSpeeds() {
        let profile = CameraProfile(
            name: "Test",
            shutterSpeeds: [1.0, 1.0/125, 1.0/500, 1.0/60]
        )
        let sorted = profile.sortedShutterSpeeds
        // Should be ascending (smallest → largest duration)
        for i in 0..<(sorted.count - 1) {
            #expect(sorted[i] <= sorted[i + 1])
        }
    }
}

// MARK: - LayoutOffsets Tests

struct LayoutOffsetsTests {

    @Test func defaultValues() {
        let offsets = LayoutOffsets()
        #expect(offsets.meterOffsetX == 0)
        #expect(offsets.meterOffsetY == 0)
    }

    @Test func encodeDecode() throws {
        var offsets = LayoutOffsets()
        offsets.meterOffsetX = 42.5
        offsets.meterOffsetY = -17.3
        let data = try JSONEncoder().encode(offsets)
        let decoded = try JSONDecoder().decode(LayoutOffsets.self, from: data)
        #expect(decoded.meterOffsetX == 42.5)
        #expect(decoded.meterOffsetY == -17.3)
    }

    @Test func saveAndLoad() {
        // Clean up first
        UserDefaults.standard.removeObject(forKey: "svit.layout")

        var offsets = LayoutOffsets()
        offsets.meterOffsetX = 100
        offsets.meterOffsetY = -50
        offsets.save()

        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 100)
        #expect(loaded.meterOffsetY == -50)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "svit.layout")
    }

    @Test func loadReturnsDefaultWhenEmpty() {
        UserDefaults.standard.removeObject(forKey: "svit.layout")
        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 0)
        #expect(loaded.meterOffsetY == 0)
    }
}

// MARK: - Standard Values Tests

struct StandardValuesTests {

    @Test func standardAperturesAreSorted() {
        let apertures = ExposureCalculator.standardApertures
        for i in 0..<(apertures.count - 1) {
            #expect(apertures[i] < apertures[i + 1])
        }
    }

    @Test func standardShutterSpeedsAreSorted() {
        let speeds = ExposureCalculator.standardShutterSpeeds
        for i in 0..<(speeds.count - 1) {
            #expect(speeds[i] < speeds[i + 1])
        }
    }

    @Test func standardISOsAreSorted() {
        let isos = ExposureCalculator.standardISOs
        for i in 0..<(isos.count - 1) {
            #expect(isos[i] < isos[i + 1])
        }
    }

    @Test func standardISOsAreFullStops() {
        // Each ISO should be double the previous
        let isos = ExposureCalculator.standardISOs
        for i in 1..<isos.count {
            #expect(isos[i] == isos[i - 1] * 2)
        }
    }
}
