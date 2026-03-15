import Testing
import Foundation
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

    @Test func nextCyclesForward() {
        #expect(PreviewMode.histogram.next == .camera)
        #expect(PreviewMode.camera.next == .game)
        #expect(PreviewMode.game.next == .runner)
        #expect(PreviewMode.runner.next == .histogram)
    }

    @Test func previousCyclesBackward() {
        #expect(PreviewMode.histogram.previous == .runner)
        #expect(PreviewMode.runner.previous == .game)
        #expect(PreviewMode.game.previous == .camera)
        #expect(PreviewMode.camera.previous == .histogram)
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

// MARK: - LayoutOffsets

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
        UserDefaults.standard.removeObject(forKey: "zrno.layout")
        var offsets = LayoutOffsets()
        offsets.meterOffsetX = 100
        offsets.meterOffsetY = -50
        offsets.save()
        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 100)
        #expect(loaded.meterOffsetY == -50)
        UserDefaults.standard.removeObject(forKey: "zrno.layout")
    }

    @Test func loadReturnsDefaultWhenEmpty() {
        UserDefaults.standard.removeObject(forKey: "zrno.layout")
        let loaded = LayoutOffsets.load()
        #expect(loaded.meterOffsetX == 0)
        #expect(loaded.meterOffsetY == 0)
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
