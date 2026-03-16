import Testing
import Foundation
import AVFoundation
@testable import Zrno

// MARK: - CameraProfile

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
        let profile = CameraProfile(name: "Test", apertures: [8.0, 2.8, 16.0, 1.4, 5.6])
        #expect(profile.sortedApertures == [1.4, 2.8, 5.6, 8.0, 16.0])
    }

    @Test func sortedShutterSpeeds() {
        let profile = CameraProfile(name: "Test", shutterSpeeds: [1.0, 1.0/125, 1.0/500, 1.0/60])
        let sorted = profile.sortedShutterSpeeds
        for i in 0..<(sorted.count - 1) {
            #expect(sorted[i] <= sorted[i + 1])
        }
    }

    @Test func activeAperturesFallsBackToProfileApertures() {
        let profile = CameraProfile(name: "Test", apertures: [2.8, 4.0, 5.6, 8.0])
        #expect(profile.activeApertures == [2.8, 4.0, 5.6, 8.0])
    }

    @Test func activeAperturesUsesSortedProfileApertures() {
        let profile = CameraProfile(name: "Test", apertures: [8.0, 2.8, 16.0, 5.6])
        #expect(profile.activeApertures == [2.8, 5.6, 8.0, 16.0])
    }

    @Test func basicProfileDefaults() {
        #expect(CameraProfile.basicApertures == [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0])
        #expect(!CameraProfile.basicShutterSpeeds.isEmpty)
    }
}

// MARK: - CameraType

struct CameraTypeTests {

    @Test func defaultTypeIsClassic() {
        let profile = CameraProfile(name: "Test")
        #expect(profile.type == .classic)
    }

    @Test func typeRoundTrips() {
        let profile = CameraProfile(name: "Test")
        profile.type = .pinhole
        #expect(profile.type == .pinhole)
        #expect(profile.cameraType == "pinhole")

        profile.type = .classic
        #expect(profile.type == .classic)
        #expect(profile.cameraType == "classic")
    }

    @Test func effectivePinholeApertureFromDimensions() {
        let profile = CameraProfile(name: "Test")
        profile.pinholeDiameterMM = 0.3
        profile.pinholeFocalLengthMM = 75.0
        #expect(abs(profile.effectivePinholeAperture - 250.0) < 0.1)
    }

    @Test func effectivePinholeApertureFallsBackToDirectValue() {
        let profile = CameraProfile(name: "Test")
        profile.pinholeDiameterMM = 0
        profile.pinholeAperture = 128.0
        #expect(abs(profile.effectivePinholeAperture - 128.0) < 0.01)
    }
}

// MARK: - Lens

struct LensModelTests {

    @Test func lensDefaults() {
        let lens = Lens()
        #expect(lens.name == "Standard Lens")
        #expect(lens.focalLength == 50)
        #expect(lens.isSelected == false)
        #expect(!lens.apertures.isEmpty)
    }

    @Test func lensCustomValues() {
        let lens = Lens(
            name: "Summicron 50mm",
            focalLength: 50,
            apertures: [2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
            isSelected: true
        )
        #expect(lens.name == "Summicron 50mm")
        #expect(lens.focalLength == 50)
        #expect(lens.isSelected == true)
        #expect(lens.apertures.count == 7)
    }

    @Test func lensSortedApertures() {
        let lens = Lens(name: "Test", focalLength: 35, apertures: [8.0, 2.0, 16.0, 1.4, 5.6])
        #expect(lens.sortedApertures == [1.4, 2.0, 5.6, 8.0, 16.0])
    }
}

// MARK: - PreviewMode

struct PreviewModeTests {

    @Test func allCasesOrder() {
        let all = PreviewMode.allCases
        #expect(all.count == 4)
        #expect(all[0] == .histogram)
        #expect(all[1] == .camera)
        #expect(all[2] == .game)
        #expect(all[3] == .runner)
    }

    @Test func nextCyclesForwardFunOn() {
        #expect(PreviewMode.histogram.next(funMode: true) == .camera)
        #expect(PreviewMode.camera.next(funMode: true) == .game)
        #expect(PreviewMode.game.next(funMode: true) == .runner)
        #expect(PreviewMode.runner.next(funMode: true) == .histogram)
    }

    @Test func previousCyclesBackwardFunOn() {
        #expect(PreviewMode.histogram.previous(funMode: true) == .runner)
        #expect(PreviewMode.runner.previous(funMode: true) == .game)
        #expect(PreviewMode.game.previous(funMode: true) == .camera)
        #expect(PreviewMode.camera.previous(funMode: true) == .histogram)
    }

    @Test func nextCyclesForwardFunOff() {
        #expect(PreviewMode.histogram.next(funMode: false) == .camera)
        #expect(PreviewMode.camera.next(funMode: false) == .histogram)
    }

    @Test func previousCyclesBackwardFunOff() {
        #expect(PreviewMode.histogram.previous(funMode: false) == .camera)
        #expect(PreviewMode.camera.previous(funMode: false) == .histogram)
    }

    @Test func nextThenPreviousRoundTrips() {
        for mode in PreviewMode.allCases {
            #expect(mode.next(funMode: true).previous(funMode: true) == mode)
        }
        for mode in PreviewMode.available(funMode: false) {
            #expect(mode.next(funMode: false).previous(funMode: false) == mode)
        }
    }

    @Test func previousThenNextRoundTrips() {
        for mode in PreviewMode.allCases {
            #expect(mode.previous(funMode: true).next(funMode: true) == mode)
        }
        for mode in PreviewMode.available(funMode: false) {
            #expect(mode.previous(funMode: false).next(funMode: false) == mode)
        }
    }

    @Test func rawValues() {
        #expect(PreviewMode.histogram.rawValue == 0)
        #expect(PreviewMode.camera.rawValue == 1)
        #expect(PreviewMode.game.rawValue == 2)
        #expect(PreviewMode.runner.rawValue == 3)
    }

    @Test func encodeDecode() throws {
        for mode in PreviewMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PreviewMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

// MARK: - MeterMode

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

// MARK: - MeterReliability

struct MeterReliabilityTests {

    @Test func equalityCases() {
        #expect(MeterReliability.normal == MeterReliability.normal)
        #expect(MeterReliability.lowLight == MeterReliability.lowLight)
        #expect(MeterReliability.overExposed == MeterReliability.overExposed)
        #expect(MeterReliability.normal != MeterReliability.lowLight)
        #expect(MeterReliability.lowLight != MeterReliability.overExposed)
    }
}

// MARK: - ExposureStatus

struct ExposureStatusTests {

    @Test func equalityCases() {
        #expect(ExposureStatus.correct == ExposureStatus.correct)
        #expect(ExposureStatus.underExposed == ExposureStatus.underExposed)
        #expect(ExposureStatus.overExposed == ExposureStatus.overExposed)
        #expect(ExposureStatus.correct != ExposureStatus.underExposed)
        #expect(ExposureStatus.underExposed != ExposureStatus.overExposed)
    }
}

// MARK: - PreviewMode (extended)

struct PreviewModeAvailableTests {

    @Test func availableFunOn() {
        let modes = PreviewMode.available(funMode: true)
        #expect(modes == PreviewMode.allCases)
    }

    @Test func availableFunOff() {
        let modes = PreviewMode.available(funMode: false)
        #expect(modes == [.histogram, .camera])
        #expect(!modes.contains(.game))
        #expect(!modes.contains(.runner))
    }

    @Test func gameModeNextFunOffFallsToHistogram() {
        // If somehow on .game with fun off, next should wrap to histogram
        let next = PreviewMode.game.next(funMode: false)
        #expect(next == .histogram)
    }

    @Test func gameModeePreviousFunOffFallsToHistogram() {
        let prev = PreviewMode.game.previous(funMode: false)
        #expect(prev == .histogram)
    }
}

// MARK: - CameraProfile (extended)

struct CameraProfileExtendedTests {

    @Test func activeAperturesUsesSelectedLens() {
        let profile = CameraProfile(name: "Test", apertures: [2.8, 4.0, 5.6])
        let lens = Lens(name: "Wide", focalLength: 35, apertures: [1.4, 2.0, 2.8], isSelected: true)
        lens.cameraProfile = profile
        profile.lenses = [lens]
        let active = profile.activeApertures
        #expect(active == [1.4, 2.0, 2.8])
    }

    @Test func activeAperturesFallsBackWhenNoLensSelected() {
        let profile = CameraProfile(name: "Test", apertures: [4.0, 5.6, 8.0])
        let lens = Lens(name: "Wide", focalLength: 35, apertures: [1.4, 2.0], isSelected: false)
        lens.cameraProfile = profile
        profile.lenses = [lens]
        let active = profile.activeApertures
        #expect(active == [4.0, 5.6, 8.0])
    }

    @Test func pinholeTypeProperties() {
        let profile = CameraProfile(name: "Pinhole")
        profile.type = .pinhole
        profile.pinholeDiameterMM = 0.5
        profile.pinholeFocalLengthMM = 100.0
        #expect(profile.type == .pinhole)
        #expect(abs(profile.effectivePinholeAperture - 200.0) < 0.1)
    }

    @Test func exposureCompensationDefault() {
        let profile = CameraProfile(name: "Test")
        #expect(profile.exposureCompensation == 0.0)
    }

    @Test func isDefaultFlagWorks() {
        let profile = CameraProfile(name: "Basic")
        profile.isDefault = true
        #expect(profile.isDefault == true)
    }
}

// MARK: - CameraLens

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
