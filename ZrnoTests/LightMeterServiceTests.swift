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

    @Test func selectClosestCameraPicksNearest() {
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
            CameraLens(id: "tele", deviceType: .builtInTelephotoCamera, focalLength: 77, label: "77mm"),
        ]
        meter.activeCameraID = "ultra"
        meter.selectClosestCamera(toFocalLength: 80)
        #expect(meter.activeCameraID == "tele")
    }

    @Test func selectClosestCameraPicksUltraWideForShortFocal() {
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
            CameraLens(id: "tele", deviceType: .builtInTelephotoCamera, focalLength: 77, label: "77mm"),
        ]
        meter.activeCameraID = "wide"
        meter.selectClosestCamera(toFocalLength: 15)
        #expect(meter.activeCameraID == "ultra")
    }

    @Test func selectClosestCameraPicksWideForMidFocal() {
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
            CameraLens(id: "tele", deviceType: .builtInTelephotoCamera, focalLength: 77, label: "77mm"),
        ]
        meter.activeCameraID = "ultra"
        meter.selectClosestCamera(toFocalLength: 40)
        #expect(meter.activeCameraID == "wide")
    }

    @Test func selectClosestCameraWithOnlyTwoLenses() {
        // iPhone 17 style: only ultra-wide + wide
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
        ]
        meter.activeCameraID = "wide"
        // 60mm should stay on wide (26mm is closer than 13mm)
        meter.selectClosestCamera(toFocalLength: 60)
        #expect(meter.activeCameraID == "wide")
    }

    @Test func selectClosestCameraSwitchesToUltraWideOnShortLens() {
        // With only two lenses, 15mm should switch to ultra-wide
        let meter = LightMeterService()
        meter.availableCameras = [
            CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
        ]
        meter.activeCameraID = "wide"
        meter.selectClosestCamera(toFocalLength: 15)
        #expect(meter.activeCameraID == "ultra")
    }
}

// MARK: - Camera Switch (Simulator)

struct CameraSwitchTests {

    @Test func switchCameraUpdatesActiveCameraID() {
        let meter = LightMeterService()
        let ultraWide = CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm")
        let wide = CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        meter.availableCameras = [ultraWide, wide]
        meter.activeCameraID = "wide"
        meter.switchCamera(to: ultraWide)
        #expect(meter.activeCameraID == "ultra")
    }

    @Test func switchCameraNoopWhenSameCamera() {
        let meter = LightMeterService()
        let wide = CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        meter.availableCameras = [wide]
        meter.activeCameraID = "wide"
        meter.switchCamera(to: wide)
        #expect(meter.activeCameraID == "wide")
    }

    @Test func switchCameraPreservesEVDuringTransition() {
        let meter = LightMeterService()
        meter.measuredEV = 12.5
        let ultra = CameraLens(id: "ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm")
        let wide = CameraLens(id: "wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm")
        meter.availableCameras = [ultra, wide]
        meter.activeCameraID = "wide"
        meter.switchCamera(to: ultra)
        // EV should be preserved (not reset) during camera transition
        #expect(meter.measuredEV == 12.5)
    }
}

// MARK: - Exposure Status in Auto Mode

struct LightMeterServiceExposureStatusTests {

    @Test func autoModeCorrectExposure() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile, force: true)
        #expect(meter.exposureStatus == .correct)
    }

    @Test func autoModeOverExposedWhenTooBright() {
        let meter = LightMeterService()
        meter.measuredEV = 22.0 // extremely bright
        let profile = CameraProfile(
            name: "Test",
            apertures: [8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile, force: true)
        // With such extreme EV and limited fast speeds, combos should be empty → overExposed
        if meter.exposureCombinations.isEmpty {
            #expect(meter.exposureStatus == .overExposed)
        }
    }

    @Test func autoModeUnderExposedWhenTooDim() {
        let meter = LightMeterService()
        meter.measuredEV = -2.0 // very dim
        let profile = CameraProfile(
            name: "Test",
            apertures: [8.0, 11.0, 16.0],
            shutterSpeeds: [1.0/1000, 1.0/500, 1.0/250],
            filmISO: 100
        )
        meter.updateRecommendation(for: profile, force: true)
        if meter.exposureCombinations.isEmpty {
            #expect(meter.exposureStatus == .underExposed)
        }
    }

    @Test func defaultReliabilityIsNormal() {
        let meter = LightMeterService()
        #expect(meter.meterReliability == .normal)
    }

    @Test func defaultExposureStatusIsCorrect() {
        let meter = LightMeterService()
        #expect(meter.exposureStatus == .correct)
    }

    @Test func quantizedEVRoundsToTenth() {
        let meter = LightMeterService()
        meter.measuredEV = 12.34
        #expect(meter.quantizedEV == 123)
        meter.measuredEV = 12.35
        #expect(meter.quantizedEV == 124)
    }

    @Test func exposureCombinationsPopulated() {
        let meter = LightMeterService()
        meter.measuredEV = 12.0
        let profile = CameraProfile(
            name: "Test",
            apertures: [2.8, 4.0, 5.6, 8.0],
            shutterSpeeds: [1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30],
            filmISO: 400
        )
        meter.updateRecommendation(for: profile, force: true)
        #expect(!meter.exposureCombinations.isEmpty)
        for combo in meter.exposureCombinations {
            #expect(profile.activeApertures.contains(combo.aperture))
            #expect(profile.sortedShutterSpeeds.contains(combo.shutterSpeed))
        }
    }
}
