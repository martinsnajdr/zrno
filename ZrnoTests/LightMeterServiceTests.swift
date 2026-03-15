import Testing
import Foundation
import AVFoundation
@testable import Zrno

// MARK: - Priority Mode

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
        meter.toggleShutterPriority(currentShutter: 1.0 / 60)
        #expect(meter.meterMode == .shutterPriority)
        #expect(meter.lockedAperture == nil)
        #expect(meter.lockedShutterSpeed == 1.0 / 60)
    }

    @Test func setLockedApertureUpdatesValue() {
        let meter = LightMeterService()
        meter.toggleAperturePriority(currentAperture: 5.6)
        meter.setLockedAperture(8.0)
        #expect(meter.lockedAperture == 8.0)
    }

    @Test func setLockedShutterSpeedUpdatesValue() {
        let meter = LightMeterService()
        meter.toggleShutterPriority(currentShutter: 1.0 / 125)
        meter.setLockedShutterSpeed(1.0 / 60)
        #expect(meter.lockedShutterSpeed == 1.0 / 60)
    }
}

// MARK: - Recommendation

struct LightMeterServiceRecommendationTests {

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
        #expect(meter.recommendedAperture == 8.0)
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
        #expect(meter.recommendedShutterSpeed == 1.0 / 125)
        #expect(meter.recommendedAperture > 0)
    }

    @Test func pinholeRecommendationSetsCorrectMode() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        let profile = CameraProfile(name: "Pinhole", filmISO: 100)
        profile.type = .pinhole
        profile.pinholeAperture = 256.0
        profile.schwarzschildP = 1.31
        meter.updateRecommendation(for: profile, force: true)
        #expect(meter.isPinholeMode == true)
        #expect(meter.recommendedAperture == 256.0)
        #expect(meter.recommendedShutterSpeed > 0)
        #expect(meter.uncorrectedShutterSpeed > 0)
    }

    @Test func pinholeRecommendationAppliesSchwarzschild() {
        let meter = LightMeterService()
        meter.measuredEV = 8.0 // dim enough to produce > 1s exposure at f/256
        let profile = CameraProfile(name: "Pinhole", filmISO: 100)
        profile.type = .pinhole
        profile.pinholeAperture = 256.0
        profile.schwarzschildP = 1.31
        meter.updateRecommendation(for: profile, force: true)
        // Corrected should be longer than uncorrected for exposures > 1s
        if meter.uncorrectedShutterSpeed > 1.0 {
            #expect(meter.recommendedShutterSpeed > meter.uncorrectedShutterSpeed)
        }
    }

    @Test func autoModeRecommendation() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 5.6, 8.0, 11.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile, force: true)
        #expect(meter.isPinholeMode == false)
        #expect(profile.activeApertures.contains(meter.recommendedAperture))
        #expect(profile.sortedShutterSpeeds.contains(meter.recommendedShutterSpeed))
    }

    @Test func compensationAffectsRecommendation() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        let profile = CameraProfile(
            name: "Test",
            apertures: [5.6],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 100
        )
        profile.exposureCompensation = 0.0
        meter.updateRecommendation(for: profile, force: true)
        let baseShutter = meter.recommendedShutterSpeed

        profile.exposureCompensation = 2.0
        meter.updateRecommendation(for: profile, force: true)
        #expect(meter.recommendedShutterSpeed >= baseShutter)
    }
}

// MARK: - Debounce

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
        meter.updateRecommendation(for: profile, force: true)
        let initialShutter = meter.recommendedShutterSpeed
        meter.measuredEV = 12.05
        meter.updateRecommendation(for: profile)
        #expect(meter.recommendedShutterSpeed == initialShutter)
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
        meter.measuredEV = 12.01
        meter.updateRecommendation(for: profile, force: true)
        #expect(meter.recommendedAperture > 0)
    }
}

// MARK: - Focal Length Selection

struct FocalLengthSelectionTests {

    @Test func selectClosestCameraNoopWhenAlreadySelected() {
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
        ]
        meter.activeCameraID = "wide"
        meter.selectClosestCamera(toFocalLength: 26)
        #expect(meter.activeCameraID == "wide")
    }

    @Test func selectClosestCameraEmptyCameras() {
        let meter = LightMeterService()
        meter.availableCameras = []
        meter.activeCameraID = ""
        meter.selectClosestCamera(toFocalLength: 50)
        #expect(meter.activeCameraID == "")
    }
}
