import Foundation

enum ExposureCalculator {

    // MARK: - Standard Photography Stops

    static let standardApertures: [Double] = [
        0.7, 0.8, 0.95, 1.0, 1.1, 1.2, 1.4, 1.5, 1.7, 1.8,
        2.0, 2.2, 2.4, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5, 5.0,
        5.6, 6.3, 7.1, 8.0, 9.0, 10.0, 11.0, 13.0, 14.0, 16.0,
        18.0, 20.0, 22.0, 25.0, 29.0, 32.0, 36.0, 40.0, 45.0, 64.0
    ]

    static let standardShutterSpeeds: [Double] = [
        1.0 / 12000, 1.0 / 8000, 1.0 / 6000, 1.0 / 4000,
        1.0 / 2000, 1.0 / 1000, 1.0 / 500, 1.0 / 250,
        1.0 / 125, 1.0 / 60, 1.0 / 30, 1.0 / 15, 1.0 / 8,
        1.0 / 4, 1.0 / 2, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0
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
    /// When `calibration` is provided, uses actual (measured) speeds for accuracy
    /// while returning the nominal (dial) speed for display.
    static func bestExposure(
        ev100: Double,
        filmISO: Int,
        availableApertures: [Double],
        availableShutterSpeeds: [Double],
        compensation: Double = 0.0,
        calibration: ((Double) -> Double)? = nil
    ) -> (aperture: Double, shutterSpeed: Double) {
        let adjustedEV = ev100 - compensation
        var bestPair: (Double, Double) = (
            availableApertures.first ?? 5.6,
            availableShutterSpeeds.first ?? 1.0 / 125
        )
        var bestError: Double = .infinity

        for aperture in availableApertures {
            let idealShutter = self.shutterSpeed(forAperture: aperture, ev100: adjustedEV, filmISO: filmISO)
            guard idealShutter > 0 else { continue }
            if let nearest = availableShutterSpeeds.min(by: {
                let actual0 = calibration?($0) ?? $0
                let actual1 = calibration?($1) ?? $1
                return abs(log2(actual0) - log2(idealShutter)) < abs(log2(actual1) - log2(idealShutter))
            }) {
                let actualNearest = calibration?(nearest) ?? nearest
                let error = abs(log2(actualNearest) - log2(idealShutter))
                // Prefer combos near f/8 + 1/60s when errors are within 1 stop
                let newApertureDist = abs(log2(aperture) - log2(8.0))
                let newShutterDist = abs(log2(nearest) - log2(1.0 / 60.0))
                let oldApertureDist = abs(log2(bestPair.0) - log2(8.0))
                let oldShutterDist = abs(log2(bestPair.1) - log2(1.0 / 60.0))
                let newScore = newApertureDist + newShutterDist
                let oldScore = oldApertureDist + oldShutterDist
                if error < bestError - 1.0 || (error < bestError + 1.0 && newScore < oldScore) {
                    bestError = error
                    bestPair = (aperture, nearest)
                }
            }
        }

        return bestPair
    }

    /// Generate all exposure combinations for the current light level.
    /// When `calibration` is provided, uses actual (measured) speeds for accuracy
    /// while returning the nominal (dial) speed for display.
    static func allCombinations(
        ev100: Double,
        filmISO: Int,
        availableApertures: [Double],
        availableShutterSpeeds: [Double],
        compensation: Double = 0.0,
        calibration: ((Double) -> Double)? = nil
    ) -> [(aperture: Double, shutterSpeed: Double)] {
        let adjustedEV = ev100 - compensation
        return availableApertures.compactMap { aperture in
            let idealShutter = self.shutterSpeed(forAperture: aperture, ev100: adjustedEV, filmISO: filmISO)
            guard idealShutter > 0 else { return nil }
            guard let nearest = availableShutterSpeeds.min(by: {
                let actual0 = calibration?($0) ?? $0
                let actual1 = calibration?($1) ?? $1
                return abs(log2(actual0) - log2(idealShutter)) < abs(log2(actual1) - log2(idealShutter))
            }) else { return nil }
            let actualNearest = calibration?(nearest) ?? nearest
            let error = abs(log2(actualNearest) - log2(idealShutter))
            guard error < 0.67 else { return nil }
            return (aperture, nearest)
        }
    }

    // MARK: - Pinhole Exposure

    /// Known reciprocity failure exponents (Tc = Tm^p, Tm in seconds).
    static let filmReciprocityPresets: [(name: String, p: Double)] = [
        ("None", 1.0),
        ("HP5+", 1.31),
        ("FP4+", 1.26),
        ("Delta 100", 1.26),
        ("Delta 400", 1.41),
        ("Delta 3200", 1.33),
        ("Pan F+", 1.33),
        ("SFX", 1.43),
        ("XP2", 1.31),
        ("Ortho+", 1.25),
        ("Kentmere 100", 1.26),
        ("Kentmere 400", 1.30),
        ("Tri-X 400", 1.54),
        ("T-Max 100", 1.15),
        ("T-Max 400", 1.24),
        ("Portra 160", 1.30),
        ("Portra 400", 1.30),
    ]

    /// Schwarzschild reciprocity correction: Tc = Tm^p.
    /// Only applies when Tm > 1 second.
    static func schwarzschildCorrected(seconds: Double, p: Double) -> Double {
        guard seconds > 1.0 else { return seconds }
        return pow(seconds, p)
    }

    /// Compute pinhole exposure with Schwarzschild correction.
    /// Returns (uncorrected seconds, corrected seconds).
    /// Maximum pinhole exposure time: 1 day.
    static let maxPinholeExposure: Double = 86400.0

    static func pinholeExposure(
        ev100: Double,
        filmISO: Int,
        pinholeAperture: Double,
        compensation: Double = 0.0,
        schwarzschildP: Double = 1.31
    ) -> (raw: Double, corrected: Double) {
        let adjustedEV = ev100 - compensation
        let raw = shutterSpeed(forAperture: pinholeAperture, ev100: adjustedEV, filmISO: filmISO)
        let corrected = schwarzschildCorrected(seconds: raw, p: schwarzschildP)
        return (min(raw, maxPinholeExposure), min(corrected, maxPinholeExposure))
    }

    // MARK: - Nearest Value Snap

    /// Find the nearest value in an array (by log-distance for photographic stops).
    static func nearestValue(to target: Double, in values: [Double]) -> Double? {
        guard !values.isEmpty, target > 0 else { return values.first }
        return values.min(by: {
            abs(log2($0) - log2(target)) < abs(log2($1) - log2(target))
        })
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

    /// Format aperture for display: "f/0.95", "f/2.8", "f/8"
    static func formatAperture(_ aperture: Double) -> String {
        guard aperture > 0, aperture.isFinite else { return "—" }
        if aperture == floor(aperture) || abs(aperture - round(aperture)) < 0.05 {
            return "f/\(Int(round(aperture)))"
        }
        if aperture < 1.0 {
            return String(format: "f/%.2f", aperture)
        }
        return String(format: "f/%.1f", aperture)
    }

    /// Format EV for display: "12.3"
    static func formatEV(_ ev: Double) -> String {
        guard ev.isFinite else { return "—" }
        return String(format: "%.1f", ev)
    }

    /// Format long exposure times: "1/125", "45s", "2m 30s", "1h 15m"
    static func formatLongExposure(_ seconds: Double) -> String {
        guard seconds > 0, seconds.isFinite else { return "—" }
        if seconds < 1.0 {
            return formatShutterSpeed(seconds)
        }
        if seconds < 60 {
            return "\(Int(round(seconds)))s"
        }
        let totalSeconds = Int(round(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            if minutes > 0 { return "\(hours)h \(minutes)m" }
            return "\(hours)h"
        }
        if secs > 0 { return "\(minutes)m \(secs)s" }
        return "\(minutes)m"
    }
}
