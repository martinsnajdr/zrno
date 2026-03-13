import Foundation
import SwiftData

@Model
final class Lens {
    var name: String
    var focalLength: Int // mm (actual lens marking, not 35mm equiv)
    var apertures: [Double]
    var isSelected: Bool
    var createdAt: Date

    var cameraProfile: CameraProfile?

    init(
        name: String = "Standard Lens",
        focalLength: Int = 50,
        apertures: [Double] = [2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0],
        isSelected: Bool = false
    ) {
        self.name = name
        self.focalLength = focalLength
        self.apertures = apertures
        self.isSelected = isSelected
        self.createdAt = Date()
    }

    var sortedApertures: [Double] {
        apertures.sorted()
    }
}
