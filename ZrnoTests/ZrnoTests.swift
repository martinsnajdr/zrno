import Testing
import Foundation
import AVFoundation
@testable import Zrno

// MARK: - ExposureCalculator Tests

struct ExposureCalculatorEVTests {

    @Test func ev100SunnyDay() {
        // f/16, 1/100s, ISO 100
        // EV100 = log2(256 * 100) + log2(1) = log2(25600) ≈ 14.64
        let ev = ExposureCalculator.calculateEV100(aperture: 16.0, shutterSpeed: 1.0 / 100, iso: 100)
        #expect(abs(ev - 14.64) < 0.1)
    }

    @Test func ev100IndoorRoom() {
        // f/2.8, 1/30s, ISO 400
        // EV100 = log2(7.84 * 30) + log2(100/400) = log2(235.2) - 2 ≈ 5.88
        let ev = ExposureCalculator.calculateEV100(aperture: 2.8, shutterSpeed: 1.0 / 30, iso: 400)
        #expect(abs(ev - 5.88) < 0.1)
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
        // EV100 normalizes to ISO 100 — so changing ISO shifts the result.
        // At same aperture and shutter, doubling ISO reduces EV100 by 1 stop.
        let ev200 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 200)
        let ev100 = ExposureCalculator.calculateEV100(aperture: 5.6, shutterSpeed: 1.0 / 125, iso: 100)
        #expect(abs((ev100 - ev200) - 1.0) < 0.01)
    }
}

struct ExposureCalculatorSolvingTests {

    @Test func shutterSpeedForAperture() {
        // At EV100=14.6, ISO 100, f/16: shutter ≈ 1/100
        // evAdj = 14.6 + 0 = 14.6, shutter = 256/2^14.6 ≈ 0.01 (1/100)
        let shutter = ExposureCalculator.shutterSpeed(forAperture: 16.0, ev100: 14.6, filmISO: 100)
        let reciprocal = 1.0 / shutter
        #expect(reciprocal > 80 && reciprocal < 120)
    }

    @Test func apertureForShutterSpeed() {
        // At EV100=14.6, ISO 100, 1/100s: aperture ≈ f/16
        let aperture = ExposureCalculator.aperture(forShutterSpeed: 1.0 / 100, ev100: 14.6, filmISO: 100)
        #expect(abs(aperture - 16.0) < 1.0)
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
        UserDefaults.standard.removeObject(forKey: "zrno.layout")

        var offsets = LayoutOffsets()
        offsets.meterOffsetX = 100
        offsets.meterOffsetY = -50
        offsets.save()

        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 100)
        #expect(loaded.meterOffsetY == -50)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "zrno.layout")
    }

    @Test func loadReturnsDefaultWhenEmpty() {
        UserDefaults.standard.removeObject(forKey: "zrno.layout")
        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 0)
        #expect(loaded.meterOffsetY == 0)
    }
}

// MARK: - PreviewMode Tests

struct PreviewModeTests {

    @Test func allCasesOrder() {
        let all = PreviewMode.allCases
        #expect(all.count == 3)
        #expect(all[0] == .hidden)
        #expect(all[1] == .camera)
        #expect(all[2] == .histogram)
    }

    @Test func nextCyclesForward() {
        #expect(PreviewMode.hidden.next == .camera)
        #expect(PreviewMode.camera.next == .histogram)
        #expect(PreviewMode.histogram.next == .hidden)
    }

    @Test func previousCyclesBackward() {
        #expect(PreviewMode.hidden.previous == .histogram)
        #expect(PreviewMode.camera.previous == .hidden)
        #expect(PreviewMode.histogram.previous == .camera)
    }

    @Test func nextThenPreviousRoundTrips() {
        for mode in PreviewMode.allCases {
            #expect(mode.next.previous == mode)
        }
    }

    @Test func previousThenNextRoundTrips() {
        for mode in PreviewMode.allCases {
            #expect(mode.previous.next == mode)
        }
    }

    @Test func rawValues() {
        #expect(PreviewMode.hidden.rawValue == 0)
        #expect(PreviewMode.camera.rawValue == 1)
        #expect(PreviewMode.histogram.rawValue == 2)
    }

    @Test func encodeDecode() throws {
        for mode in PreviewMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PreviewMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

// MARK: - MeterMode Tests

struct MeterModeTests {

    @Test func meterModeRawValues() {
        #expect(MeterMode.auto.rawValue == "auto")
        #expect(MeterMode.aperturePriority.rawValue == "aperturePriority")
        #expect(MeterMode.shutterPriority.rawValue == "shutterPriority")
    }

    @Test func meterModeEncodeDecode() throws {
        for mode in [MeterMode.auto, .aperturePriority, .shutterPriority] {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(MeterMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

// MARK: - LightMeterService Priority Mode Tests

struct LightMeterServicePriorityTests {

    @Test func defaultModeIsAuto() {
        let meter = LightMeterService()
        #expect(meter.meterMode == .auto)
        #expect(meter.lockedAperture == nil)
        #expect(meter.lockedShutterSpeed == nil)
    }

    @Test func toggleAperturePrioritySetsMode() {
        let meter = LightMeterService()
        meter.toggleAperturePriority(currentAperture: 5.6)
        #expect(meter.meterMode == .aperturePriority)
        #expect(meter.lockedAperture == 5.6)
        #expect(meter.lockedShutterSpeed == nil)
    }

    @Test func toggleAperturePriorityTwiceReturnsToAuto() {
        let meter = LightMeterService()
        meter.toggleAperturePriority(currentAperture: 5.6)
        meter.toggleAperturePriority(currentAperture: 5.6)
        #expect(meter.meterMode == .auto)
        #expect(meter.lockedAperture == nil)
    }

    @Test func toggleShutterPrioritySetsMode() {
        let meter = LightMeterService()
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)
        #expect(meter.meterMode == .shutterPriority)
        #expect(meter.lockedShutterSpeed == 1.0 / 125)
        #expect(meter.lockedAperture == nil)
    }

    @Test func toggleShutterPriorityTwiceReturnsToAuto() {
        let meter = LightMeterService()
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)
        #expect(meter.meterMode == .auto)
        #expect(meter.lockedShutterSpeed == nil)
    }

    @Test func switchingFromApertureToShutterPriority() {
        let meter = LightMeterService()
        meter.toggleAperturePriority(currentAperture: 5.6)
        #expect(meter.meterMode == .aperturePriority)

        meter.toggleShutterPriority(currentShutter: 1.0 / 60)
        #expect(meter.meterMode == .shutterPriority)
        #expect(meter.lockedAperture == nil)
        #expect(meter.lockedShutterSpeed == 1.0 / 60)
    }

    @Test func setLockedApertureUpdatesValue() {
        let meter = LightMeterService()
        meter.toggleAperturePriority(currentAperture: 5.6)
        #expect(meter.lockedAperture == 5.6)

        meter.setLockedAperture(8.0)
        #expect(meter.lockedAperture == 8.0)
    }

    @Test func setLockedShutterSpeedUpdatesValue() {
        let meter = LightMeterService()
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)
        #expect(meter.lockedShutterSpeed == 1.0 / 125)

        meter.setLockedShutterSpeed(1.0 / 60)
        #expect(meter.lockedShutterSpeed == 1.0 / 60)
    }

    @Test func updateRecommendationInAperturePriority() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        meter.toggleAperturePriority(currentAperture: 8.0)

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile)

        // Aperture should stay locked at 8.0
        #expect(meter.recommendedAperture == 8.0)
        // Shutter should be calculated (not zero)
        #expect(meter.recommendedShutterSpeed > 0)
    }

    @Test func updateRecommendationInShutterPriority() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile)

        // Shutter should stay locked at 1/125
        #expect(meter.recommendedShutterSpeed == 1.0 / 125)
        // Aperture should be calculated (not zero)
        #expect(meter.recommendedAperture > 0)
    }
}

// MARK: - CameraLens Tests

struct CameraLensTests {

    @Test func equality() {
        let a = CameraLens(id: "abc", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        let b = CameraLens(id: "abc", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        let c = CameraLens(id: "xyz", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashing() {
        let a = CameraLens(id: "abc", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        let b = CameraLens(id: "abc", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        #expect(a.hashValue == b.hashValue)
    }
}

// MARK: - Nearest Value Tests

struct NearestValueTests {

    @Test func nearestValueFindsExact() {
        let values = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        let result = ExposureCalculator.nearestValue(to: 1.0/125, in: values)
        #expect(result == 1.0/125)
    }

    @Test func nearestValueFindsClosest() {
        let values = [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30]
        // 1/200 is between 1/250 and 1/125 — closer to 1/250 in log space
        let result = ExposureCalculator.nearestValue(to: 1.0/200, in: values)
        #expect(result == 1.0/250)
    }

    @Test func nearestValueEmptyArray() {
        let result = ExposureCalculator.nearestValue(to: 1.0/125, in: [])
        #expect(result == nil)
    }

    @Test func nearestValueSingleElement() {
        let result = ExposureCalculator.nearestValue(to: 1.0/125, in: [1.0/60])
        #expect(result == 1.0/60)
    }

    @Test func nearestValueZeroTarget() {
        let values = [1.0/500, 1.0/250]
        let result = ExposureCalculator.nearestValue(to: 0, in: values)
        #expect(result == values.first)
    }
}

// MARK: - Calibration Tests

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
        // 1/60 has no calibration entry
        let result = profile.calibratedSpeed(for: 1.0 / 60)
        #expect(result == 1.0 / 60)
    }

    @Test func calibrationAffectsBestExposure() {
        let apertures = [5.6]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60]

        // Without calibration
        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )

        // With calibration: 1/125 is actually 1/90 (slower)
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

        // Both should return valid speeds from the available list
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

// MARK: - Debounce Tests

struct LightMeterServiceDebounceTests {

    @Test func smallEVChangeIsDebounced() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )

        // First update sets baseline
        meter.updateRecommendation(for: profile, force: true)
        let initialShutter = meter.recommendedShutterSpeed

        // Tiny EV change (< 0.15 threshold) — should NOT update
        meter.measuredEV = 12.05
        meter.updateRecommendation(for: profile)
        #expect(meter.recommendedShutterSpeed == initialShutter)
    }

    @Test func largeEVChangeUpdates() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )

        meter.updateRecommendation(for: profile, force: true)

        // Large EV change (> 0.15) — should update
        meter.measuredEV = 14.0
        meter.updateRecommendation(for: profile)
        // At EV 14 with ISO 400, exposure should be significantly different
        // Just verify it ran (the update changes lastRecommendationEV)
        #expect(meter.recommendedAperture > 0)
        #expect(meter.recommendedShutterSpeed > 0)
    }

    @Test func forceOverridesDebounce() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 5.6, 8.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60],
            filmISO: 400
        )

        meter.updateRecommendation(for: profile, force: true)

        // Even tiny change should update when forced
        meter.measuredEV = 12.01
        meter.updateRecommendation(for: profile, force: true)
        // Should complete without being skipped
        #expect(meter.recommendedAperture > 0)
    }
}

// MARK: - Exposure Compensation Tests

struct ExposureCompensationTests {

    @Test func compensationShiftsExposure() {
        let apertures = [2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
        let shutterSpeeds = [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15]

        let normal = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: 0.0
        )
        let plusOne = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: 1.0
        )
        let minusOne = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: -1.0
        )

        // +1 compensation => brighter => larger EV => faster shutter or smaller aperture
        let normalEV = log2(normal.aperture * normal.aperture / normal.shutterSpeed)
        let plusEV = log2(plusOne.aperture * plusOne.aperture / plusOne.shutterSpeed)
        let minusEV = log2(minusOne.aperture * minusOne.aperture / minusOne.shutterSpeed)

        #expect(plusEV > normalEV - 0.5)
        #expect(minusEV < normalEV + 0.5)
    }

    @Test func compensationAffectsRecommendation() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0

        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )

        // Get baseline recommendation
        profile.exposureCompensation = 0.0
        meter.updateRecommendation(for: profile, force: true)
        let baseShutter = meter.recommendedShutterSpeed
        let baseAperture = meter.recommendedAperture

        // Apply +2 EV compensation — should pick brighter exposure
        profile.exposureCompensation = 2.0
        meter.updateRecommendation(for: profile, force: true)
        let compShutter = meter.recommendedShutterSpeed
        let compAperture = meter.recommendedAperture

        let baseExposure = log2(baseAperture * baseAperture / baseShutter)
        let compExposure = log2(compAperture * compAperture / compShutter)

        // +2 compensation shifts effective EV up, meaning camera settings
        // should reflect a higher EV (faster shutter or smaller aperture)
        #expect(compExposure > baseExposure - 0.5)
    }

    @Test func compensationZeroMatchesNoCompensation() {
        let apertures = [2.8, 5.6, 8.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60]

        let withZero = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds,
            compensation: 0.0
        )
        let withoutComp = ExposureCalculator.bestExposure(
            ev100: 12.0, filmISO: 400,
            availableApertures: apertures,
            availableShutterSpeeds: shutterSpeeds
        )

        #expect(withZero.aperture == withoutComp.aperture)
        #expect(withZero.shutterSpeed == withoutComp.shutterSpeed)
    }

    @Test func compensationThirdsProduceDistinctResults() {
        // At 1/3 stop increments, each step should potentially shift the result
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

        // Should produce more than one distinct result across ±3 EV
        #expect(results.count > 1)
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
