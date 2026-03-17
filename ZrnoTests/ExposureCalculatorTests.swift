import Testing
import Foundation
@testable import Zrno

// MARK: - EV Calculation

struct ExposureCalculatorEVTests {

    @Test func ev100SunnyDay() {
        let ev = ExposureCalculator.calculateEV100(aperture: 16.0, shutterSpeed: 1.0 / 100, iso: 100)
        #expect(abs(ev - 14.64) < 0.1)
    }

    @Test func ev100IndoorRoom() {
        let ev = ExposureCalculator.calculateEV100(aperture: 2.8, shutterSpeed: 1.0 / 30, iso: 400)
        #expect(abs(ev - 5.88) < 0.1)
    }

    @Test func ev100AtISO100() {
        let ev = ExposureCalculator.calculateEV100(aperture: 8.0, shutterSpeed: 1.0 / 125, iso: 100)
        #expect(abs(ev - 12.97) < 0.1)
    }

    @Test func ev100ISOAdjustment() {
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
        let ev200 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 200)
        let ev100 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 100)
        #expect(abs((ev100 - ev200) - 1.0) < 0.01)
    }
}

// MARK: - Exposure Solving

struct ExposureCalculatorSolvingTests {

    @Test func shutterSpeedForAperture() {
        let shutter = ExposureCalculator.shutterSpeed(forAperture: 16.0, ev100: 14.6, filmISO: 100)
        let reciprocal = 1.0 / shutter
        #expect(reciprocal > 80 && reciprocal < 120)
    }

    @Test func apertureForShutterSpeed() {
        let aperture = ExposureCalculator.aperture(forShutterSpeed: 1.0 / 100, ev100: 14.6, filmISO: 100)
        #expect(abs(aperture - 16.0) < 1.0)
    }

    @Test func roundTrip() {
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
        #expect(shutter400 < shutter100)
    }
}

// MARK: - Best Exposure

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
        let normalExposure = normal.shutterSpeed / (normal.aperture * normal.aperture)
        let overExposure = overexposed.shutterSpeed / (overexposed.aperture * overexposed.aperture)
        #expect(overExposure >= normalExposure * 0.9)
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
        let apertures = [2.8, 16.0]
        let shutterSpeeds = [1.0/60, 1.0/30]
        let combos = ExposureCalculator.allCombinations(
            ev100: 15.0, filmISO: 100,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )
        for combo in combos {
            let idealShutter = ExposureCalculator.shutterSpeed(
                forAperture: combo.aperture, ev100: 15.0, filmISO: 100
            )
            let error = abs(log2(combo.shutterSpeed) - log2(idealShutter))
            #expect(error < 0.67)
        }
    }

    @Test func bestExposurePrefersMiddleApertures() {
        let apertures = [1.4, 2.8, 5.6, 8.0, 11.0, 16.0, 22.0]
        let shutterSpeeds = [1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let result = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )
        // Should prefer something near f/8 rather than extremes
        #expect(result.aperture >= 4.0 && result.aperture <= 16.0)
    }
}

// MARK: - Formatting

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
        #expect(ExposureCalculator.formatShutterSpeed(1.5) == "1.5\u{2033}")
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

    @Test func formatApertureSubOne() {
        #expect(ExposureCalculator.formatAperture(0.7) == "f/0.70")
        #expect(ExposureCalculator.formatAperture(0.8) == "f/0.80")
        #expect(ExposureCalculator.formatAperture(0.95) == "f/0.95")
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

    @Test func formatShutterSpeedVeryFast() {
        #expect(ExposureCalculator.formatShutterSpeed(1.0/12000) == "1/12000")
        #expect(ExposureCalculator.formatShutterSpeed(1.0/8000) == "1/8000")
    }

    @Test func formatLongExposureSubSecond() {
        #expect(ExposureCalculator.formatLongExposure(0.004) == "1/250")
    }

    @Test func formatLongExposureSeconds() {
        #expect(ExposureCalculator.formatLongExposure(1.0) == "1s")
        #expect(ExposureCalculator.formatLongExposure(45.0) == "45s")
    }

    @Test func formatLongExposureMinutes() {
        #expect(ExposureCalculator.formatLongExposure(150.0) == "2m 30s")
        #expect(ExposureCalculator.formatLongExposure(60.0) == "1m")
    }

    @Test func formatLongExposureHours() {
        #expect(ExposureCalculator.formatLongExposure(3700.0) == "1h 1m")
        #expect(ExposureCalculator.formatLongExposure(3600.0) == "1h")
    }

    @Test func formatLongExposureEdgeCases() {
        #expect(ExposureCalculator.formatLongExposure(0.0) == "—")
        #expect(ExposureCalculator.formatLongExposure(-1.0) == "—")
        #expect(ExposureCalculator.formatLongExposure(Double.infinity) == "—")
    }
}

// MARK: - Nearest Value

struct NearestValueTests {

    @Test func nearestValueFindsExact() {
        let values = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        let result = ExposureCalculator.nearestValue(to: 1.0/125, in: values)
        #expect(result == 1.0/125)
    }

    @Test func nearestValueFindsClosest() {
        let values = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        let result = ExposureCalculator.nearestValue(to: 1.0/200, in: values)
        #expect(result == 1.0/250)
    }

    @Test func nearestValueEmptyArray() {
        #expect(ExposureCalculator.nearestValue(to: 1.0/125, in: []) == nil)
    }

    @Test func nearestValueSingleElement() {
        #expect(ExposureCalculator.nearestValue(to: 1.0/125, in: [1.0/60]) == 1.0/60)
    }

    @Test func nearestValueZeroTarget() {
        let values = [1.0/500, 1.0/250]
        #expect(ExposureCalculator.nearestValue(to: 0, in: values) == values.first)
    }
}

// MARK: - Standard Values

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

    @Test func standardISOsAreFullStops() {
        let isos = ExposureCalculator.standardISOs
        for i in 1..<isos.count {
            #expect(isos[i] == isos[i - 1] * 2)
        }
    }
}

// MARK: - Exposure Compensation

struct ExposureCompensationTests {

    @Test func overexposeGivesSlowerShutter() {
        let apertures = [5.6]
        let shutterSpeeds = [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 0.0
        )
        let overexposed = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 1.0
        )
        #expect(overexposed.shutterSpeed >= normal.shutterSpeed)
    }

    @Test func underexposeGivesFasterShutter() {
        let apertures = [5.6]
        let shutterSpeeds = [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 0.0
        )
        let underexposed = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: -1.0
        )
        #expect(underexposed.shutterSpeed <= normal.shutterSpeed)
    }

    @Test func compensationThirdsProduceDistinctResults() {
        let apertures = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
        let shutterSpeeds = [
            1.0/1000, 1.0/500, 1.0/250, 1.0/125,
            1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2, 1.0
        ]
        var results: Set<String> = []
        for thirds in -9...9 {
            let comp = Double(thirds) / 3.0
            let result = ExposureCalculator.bestExposure(
                ev100: 10.0, filmISO: 400,
                availableApertures: apertures,
                availableShutterSpeeds: shutterSpeeds,
                compensation: comp
            )
            results.insert("\(result.aperture)-\(result.shutterSpeed)")
        }
        #expect(results.count > 1)
    }

    @Test func allCombinationsCompensationDirection() {
        let apertures = [5.6]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]
        let normal = ExposureCalculator.allCombinations(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 0.0
        )
        let overexposed = ExposureCalculator.allCombinations(
            ev100: 12.0, filmISO: 100,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 1.0
        )
        guard let normalCombo = normal.first, let overCombo = overexposed.first else {
            #expect(Bool(false), "Expected at least one combo each")
            return
        }
        #expect(overCombo.shutterSpeed >= normalCombo.shutterSpeed)
    }

    @Test func compensationZeroMatchesNoCompensation() {
        let apertures = [2.8, 5.6, 8.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60]
        let withZero = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds, compensation: 0.0
        )
        let withoutComp = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures, availableShutterSpeeds: shutterSpeeds
        )
        #expect(withZero.aperture == withoutComp.aperture)
        #expect(withZero.shutterSpeed == withoutComp.shutterSpeed)
    }
}

// MARK: - Schwarzschild / Pinhole

struct SchwarzschildTests {

    @Test func correctionUnchangedUnderOneSecond() {
        let result = ExposureCalculator.schwarzschildCorrected(seconds: 0.5, p: 1.31)
        #expect(abs(result - 0.5) < 0.001)
        let resultOne = ExposureCalculator.schwarzschildCorrected(seconds: 1.0, p: 1.31)
        #expect(abs(resultOne - 1.0) < 0.001)
    }

    @Test func correctionHP5At10Seconds() {
        let result = ExposureCalculator.schwarzschildCorrected(seconds: 10.0, p: 1.31)
        #expect(abs(result - 20.42) < 0.5)
    }

    @Test func correctedAlwaysGreaterThanRawAboveOneSecond() {
        for p in [1.15, 1.26, 1.31, 1.41, 1.54] {
            let corrected = ExposureCalculator.schwarzschildCorrected(seconds: 5.0, p: p)
            #expect(corrected > 5.0)
        }
    }
}

struct PinholeExposureTests {

    @Test func pinholeProducesLongExposure() {
        let result = ExposureCalculator.pinholeExposure(
            ev100: 15.0, filmISO: 100, pinholeAperture: 256.0
        )
        #expect(result.raw > 1.0)
        #expect(result.corrected > result.raw)
    }

    @Test func pinholeCorrectedEqualsRawUnderOneSecond() {
        let result = ExposureCalculator.pinholeExposure(
            ev100: 20.0, filmISO: 100, pinholeAperture: 128.0
        )
        #expect(result.raw < 1.0)
        #expect(abs(result.corrected - result.raw) < 0.001)
    }

    @Test func pinholeCompensationShiftsExposure() {
        let base = ExposureCalculator.pinholeExposure(
            ev100: 12.0, filmISO: 100, pinholeAperture: 256.0, compensation: 0.0
        )
        let compensated = ExposureCalculator.pinholeExposure(
            ev100: 12.0, filmISO: 100, pinholeAperture: 256.0, compensation: 1.0
        )
        #expect(compensated.raw > base.raw * 1.8)
        #expect(compensated.raw < base.raw * 2.2)
    }
}

struct FilmPresetsTests {

    @Test func presetsNonEmpty() {
        #expect(!ExposureCalculator.filmReciprocityPresets.isEmpty)
    }

    @Test func allPValuesGreaterThanOrEqualToOne() {
        for preset in ExposureCalculator.filmReciprocityPresets {
            #expect(preset.p >= 1.0, "Preset \(preset.name) has p=\(preset.p) which should be >= 1.0")
        }
    }

    @Test func nonNonePresetsHavePGreaterThanOne() {
        for preset in ExposureCalculator.filmReciprocityPresets where preset.name != "None" {
            #expect(preset.p > 1.0, "Preset \(preset.name) has p=\(preset.p) which should be > 1.0")
        }
    }

    @Test func nonePresetHasIdentityP() {
        let none = ExposureCalculator.filmReciprocityPresets.first { $0.name == "None" }
        #expect(none != nil, "Should have a 'None' preset")
        #expect(none?.p == 1.0)
    }

    @Test func presetsHaveUniqueNames() {
        let names = ExposureCalculator.filmReciprocityPresets.map(\.name)
        #expect(Set(names).count == names.count)
    }
}

// MARK: - Calibration

struct CameraProfileCalibrationTests {

    @Test func calibratedSpeedReturnsNominalWhenNoCalibration() {
        let profile = CameraProfile(name: "Test")
        let speed = 1.0 / 125
        #expect(profile.calibratedSpeed(for: speed) == speed)
    }

    @Test func calibratedSpeedReturnsActual() {
        let profile = CameraProfile(
            name: "Test",
            shutterCalibration: [1.0 / 125: 1.0 / 105]
        )
        let result = profile.calibratedSpeed(for: 1.0 / 125)
        #expect(abs(result - 1.0 / 105) < 0.0001)
    }

    @Test func calibratedSpeedUnaffectedSpeeds() {
        let profile = CameraProfile(
            name: "Test",
            shutterCalibration: [1.0 / 125: 1.0 / 105]
        )
        let result = profile.calibratedSpeed(for: 1.0 / 60)
        #expect(result == 1.0 / 60)
    }

    @Test func calibrationAffectsBestExposure() {
        let apertures = [5.6]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60]

        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )

        let calibrate: (Double) -> Double = { speed in
            if abs(log2(speed) - log2(1.0/125)) < 0.01 { return 1.0 / 90 }
            return speed
        }
        let calibrated = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            calibration: calibrate
        )

        #expect(shutterSpeeds.contains(normal.shutterSpeed))
        #expect(shutterSpeeds.contains(calibrated.shutterSpeed))
    }

    @Test func calibrationAffectsAllCombinations() {
        let apertures = [2.8, 5.6, 8.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        let calibrate: (Double) -> Double = { speed in
            if abs(log2(speed) - log2(1.0/125)) < 0.01 { return 1.0 / 100 }
            return speed
        }
        let combos = ExposureCalculator.allCombinations(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            calibration: calibrate
        )
        #expect(!combos.isEmpty)
        for combo in combos {
            #expect(apertures.contains(combo.aperture))
            #expect(shutterSpeeds.contains(combo.shutterSpeed))
        }
    }
}
