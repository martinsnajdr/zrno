import Foundation
import SwiftData

@Model
final class CameraProfile {
    var name: String
    var apertures: [Double]
    var shutterSpeeds: [Double]
    var filmISO: Int
    var exposureCompensation: Double
    var isSelected: Bool
    var createdAt: Date

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
        isSelected: Bool = false
    ) {
        self.name = name
        self.apertures = apertures
        self.shutterSpeeds = shutterSpeeds
        self.filmISO = filmISO
        self.exposureCompensation = exposureCompensation
        self.isSelected = isSelected
        self.createdAt = Date()
    }

    /// Sorted apertures ascending (f/1.4 → f/16)
    var sortedApertures: [Double] {
        apertures.sorted()
    }

    /// Sorted shutter speeds descending (fastest → slowest: 1/1000 → 1″)
    var sortedShutterSpeeds: [Double] {
        shutterSpeeds.sorted()
    }
}
