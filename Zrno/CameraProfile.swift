import Foundation
import SwiftData

enum CameraType: String, Codable, CaseIterable {
    case classic
    case pinhole
}

@Model
final class CameraProfile {
    var name: String
    var apertures: [Double]
    var shutterSpeeds: [Double]
    var filmISO: Int
    var exposureCompensation: Double
    var isSelected: Bool
    var createdAt: Date

    /// Shutter speed calibration: maps nominal speeds (dial markings) to actual measured speeds.
    var shutterCalibration: [Double: Double]

    /// Whether this is the built-in default profile (cannot be deleted).
    var isDefault: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Lens.cameraProfile)
    var lenses: [Lens]

    // MARK: - Camera Type

    /// Stored as String for SwiftData compatibility.
    var cameraType: String = "classic"

    /// Convenience accessor for the camera type enum.
    var type: CameraType {
        get { CameraType(rawValue: cameraType) ?? .classic }
        set { cameraType = newValue.rawValue }
    }

    // MARK: - Pinhole Properties

    /// Effective f-number of the pinhole (e.g. 128, 256).
    var pinholeAperture: Double = 128.0

    /// Physical pinhole diameter in mm (0 = not set, user entered f directly).
    var pinholeDiameterMM: Double = 0.0

    /// Focal length in mm (0 = not set).
    var pinholeFocalLengthMM: Double = 0.0

    /// Schwarzschild reciprocity correction exponent.
    var schwarzschildP: Double = 1.0

    /// Name of selected film reciprocity preset ("Custom" if manually overridden).
    var filmPreset: String = "None"

    /// Effective pinhole aperture computed from diameter and focal length.
    var computedPinholeAperture: Double? {
        guard pinholeDiameterMM > 0, pinholeFocalLengthMM > 0 else { return nil }
        return pinholeFocalLengthMM / pinholeDiameterMM
    }

    /// The actual pinhole f-number to use: computed from dimensions if available, otherwise the direct value.
    var effectivePinholeAperture: Double {
        computedPinholeAperture ?? pinholeAperture
    }

    // MARK: - Basic Profile Defaults

    static let basicApertures: [Double] = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0]
    static let basicShutterSpeeds: [Double] = [1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2, 1.0]

    init(
        name: String,
        apertures: [Double] = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
        shutterSpeeds: [Double] = [
            1.0 / 1000, 1.0 / 500, 1.0 / 250, 1.0 / 125,
            1.0 / 60, 1.0 / 30, 1.0 / 15, 1.0 / 8,
            1.0 / 4, 1.0 / 2, 1.0
        ],
        filmISO: Int = 400,
        exposureCompensation: Double = 0.0,
        isSelected: Bool = false,
        shutterCalibration: [Double: Double] = [:]
    ) {
        self.name = name
        self.apertures = apertures
        self.shutterSpeeds = shutterSpeeds
        self.filmISO = filmISO
        self.exposureCompensation = exposureCompensation
        self.isSelected = isSelected
        self.createdAt = Date()
        self.shutterCalibration = shutterCalibration
        self.lenses = []
    }

    /// The currently selected lens, if any.
    var selectedLens: Lens? {
        lenses.first(where: { $0.isSelected })
    }

    /// Active apertures from the selected lens, or fallback to profile apertures.
    var activeApertures: [Double] {
        (selectedLens?.sortedApertures ?? apertures.sorted())
    }

    /// Sorted apertures ascending (f/1.4 → f/16)
    var sortedApertures: [Double] {
        apertures.sorted()
    }

    /// Sorted shutter speeds ascending (fastest → slowest)
    var sortedShutterSpeeds: [Double] {
        shutterSpeeds.sorted()
    }

    /// Returns the actual (calibrated) speed for a nominal dial speed.
    func calibratedSpeed(for nominal: Double) -> Double {
        for (key, value) in shutterCalibration {
            if abs(log2(key) - log2(nominal)) < 0.01 {
                return value
            }
        }
        return nominal
    }
}
