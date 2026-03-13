import Foundation

enum ExposureCalculator {

    // MARK: - Standard Photography Stops

    static let standardApertures: [Double] = [1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]

    static let standardShutterSpeeds: [Double] = [
        1.0 / 4000, 1.0 / 2000, 1.0 / 1000, 1.0 / 500, 1.0 / 250,
        1.0 / 125, 1.0 / 60, 1.0 / 30, 1.0 / 15, 1.0 / 8,
        1.0 / 4, 1.0 / 2, 1.0, 2.0, 4.0, 8.0
    ]

    static let standardISOs: [Int] = [25, 50, 100, 200, 400, 800, 1600, 3200]

    // MARK: - EV Calculation

    /// Calculate EV at ISO 100 from camera readings.
    /// EV100 = log2(N² / t) + log2(100 / S)
    static func calculateEV100(aperture: Double, shutterSpeed: Double, iso: Double) -> Double {
        guard shutterSpeed > 0, iso > 0, aperture > 0 else { return 0 }
        return log2(aperture * aperture / shutterSpeed) + log2(100.0 / iso)
    }

    // MARK: - Exposure Solving

    /// Given EV100 and film ISO, find the required shutter speed for a given aperture.
    static func shutterSpeed(forAperture aperture: Double, ev100: Double, filmISO: Int) -> Double {
        let evAdjusted = ev100 + log2(Double(filmISO) / 100.0)
        return (aperture * aperture) / pow(2.0, evAdjusted)
    }

    /// Given EV100 and film ISO, find the required aperture for a given shutter speed.
    static func aperture(forShutterSpeed shutterSpeed: Double, ev100: Double, filmISO: Int) -> Double {
        guard shutterSpeed > 0 else { return 0 }
        let evAdjusted = ev100 + log2(Double(filmISO) / 100.0)
        return sqrt(shutterSpeed * pow(2.0, evAdjusted))
    }

    /// Find the best aperture/shutter combo from available options on the camera profile.
    static func bestExposure(
        ev100: Double,
        filmISO: Int,
        availableApertures: [Double],
        availableShutterSpeeds: [Double],
        compensation: Double = 0.0
    ) -> (aperture: Double, shutterSpeed: Double) {
        let adjustedEV = ev100 + compensation
        var bestPair: (Double, Double) = (
            availableApertures.first ?? 5.6,
            availableShutterSpeeds.first ?? 1.0 / 125
        )
        var bestError: Double = .infinity

        for aperture in availableApertures {
            let idealShutter = self.shutterSpeed(forAperture: aperture, ev100: adjustedEV, filmISO: filmISO)
            guard idealShutter > 0 else { continue }
            if let nearest = availableShutterSpeeds.min(by: {
                abs(log2($0) - log2(idealShutter)) < abs(log2($1) - log2(idealShutter))
            }) {
                let error = abs(log2(nearest) - log2(idealShutter))
                if error < bestError {
                    bestError = error
                    bestPair = (aperture, nearest)
                }
            }
        }

        return bestPair
    }

    /// Generate all exposure combinations for the current light level.
    static func allCombinations(
        ev100: Double,
        filmISO: Int,
        availableApertures: [Double],
        availableShutterSpeeds: [Double],
        compensation: Double = 0.0
    ) -> [(aperture: Double, shutterSpeed: Double)] {
        let adjustedEV = ev100 + compensation
        return availableApertures.compactMap { aperture in
            let idealShutter = self.shutterSpeed(forAperture: aperture, ev100: adjustedEV, filmISO: filmISO)
            guard idealShutter > 0 else { return nil }
            guard let nearest = availableShutterSpeeds.min(by: {
                abs(log2($0) - log2(idealShutter)) < abs(log2($1) - log2(idealShutter))
            }) else { return nil }
            // Only include if the error is within 2/3 stop
            let error = abs(log2(nearest) - log2(idealShutter))
            guard error < 0.67 else { return nil }
            return (aperture, nearest)
        }
    }

    // MARK: - Formatting

    /// Format shutter speed for display: "1/125", "1/60", "1″", "2″"
    static func formatShutterSpeed(_ seconds: Double) -> String {
        guard seconds > 0, seconds.isFinite else { return "—" }
        if seconds >= 1.0 {
            if seconds == floor(seconds) {
                return "\(Int(seconds))\u{2033}"
            }
            return String(format: "%.1f\u{2033}", seconds)
        }
        let reciprocal = 1.0 / seconds
        let rounded = Int(round(reciprocal))
        return "1/\(rounded)"
    }

    /// Format aperture for display: "f/2.8", "f/8"
    static func formatAperture(_ aperture: Double) -> String {
        guard aperture > 0, aperture.isFinite else { return "—" }
        if aperture == floor(aperture) || abs(aperture - round(aperture)) < 0.05 {
            return "f/\(Int(round(aperture)))"
        }
        return String(format: "f/%.1f", aperture)
    }

    /// Format EV for display: "12.3"
    static func formatEV(_ ev: Double) -> String {
        guard ev.isFinite else { return "—" }
        return String(format: "%.1f", ev)
    }
}
