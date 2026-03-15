import AVFoundation
import CoreImage
import Observation
import UIKit

// MARK: - Camera Lens

struct CameraLens: Identifiable, Hashable {
    let id: String
    let deviceType: AVCaptureDevice.DeviceType
    let focalLength: Int // 35mm equivalent
    let label: String

    static func == (lhs: CameraLens, rhs: CameraLens) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Meter Mode

enum MeterMode: String, Codable {
    case auto
    case aperturePriority
    case shutterPriority
}

enum MeterReliability: Equatable {
    case normal
    case lowLight       // camera near limits, readings approximate
    case overExposed    // sensor saturated
}

enum ExposureStatus: Equatable {
    case correct
    case underExposed
    case overExposed
}

@Observable
final class LightMeterService: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published Readings

    var measuredEV: Double = 0.0
    var cameraExposureDuration: Double = 0.0
    var cameraISO: Float = 0.0
    var cameraAperture: Float = 0.0
    var isRunning: Bool = false
    var permissionGranted: Bool = false

    // Recommended settings for the active film camera
    var recommendedAperture: Double = 5.6
    var recommendedShutterSpeed: Double = 1.0 / 125
    var exposureCombinations: [(aperture: Double, shutterSpeed: Double)] = []

    // Lo-fi preview image (monochrome, downscaled)
    var previewImage: CGImage?

    // Histogram data (256 bins for luminance)
    var histogramBins: [Float] = Array(repeating: 0, count: 256)
    private var smoothedHistogram: [Float] = Array(repeating: 0, count: 256)
    private let histogramSmoothing: Float = 0.4

    // Multi-camera
    var availableCameras: [CameraLens] = []
    var activeCameraID: String = ""

    // Reliability indicator (derived from device limits)
    var meterReliability: MeterReliability = .normal

    // Exposure status for priority modes (locked axis)
    var exposureStatus: ExposureStatus = .correct

    // Pinhole mode
    var isPinholeMode: Bool = false
    var uncorrectedShutterSpeed: Double = 0.0

    // Priority mode
    var meterMode: MeterMode = .auto
    var lockedAperture: Double?
    var lockedShutterSpeed: Double?

    // Debounce: only update displayed values when EV changes meaningfully
    private var lastRecommendationEV: Double = -.infinity
    private let recommendationThreshold: Double = 0.3 // ~1/3 stop
    private var lastRecommendationTime: Date = .distantPast
    private let recommendationInterval: TimeInterval = 0.5 // max 2x/sec

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var observations: [NSKeyValueObservation] = []
    private let sessionQueue = DispatchQueue(label: "com.zrno.session")
    private let processingQueue = DispatchQueue(label: "com.zrno.processing", qos: .userInitiated)
    private let smoothingFactor: Double = 0.15
    private var hasInitialReading = false
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    nonisolated(unsafe) private var frameSkipCounter = 0
    // Low-light extension: camera's report of how many stops off-target
    private var exposureTargetOffset: Double = 0.0

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?
    private var simulatorPhase: Double = 0
    #endif

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
        }
    }

    // MARK: - Start / Stop

    func startMetering() {
        #if targetEnvironment(simulator)
        startSimulatorMetering()
        #else
        guard permissionGranted else { return }
        discoverCameras()
        setupSession()
        observeExposure()
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
        #endif
    }

    func stopMetering() {
        #if targetEnvironment(simulator)
        simulatorTimer?.invalidate()
        simulatorTimer = nil
        #else
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
        observations.removeAll()
        #endif
    }

    // MARK: - Recommendation

    func updateRecommendation(for profile: CameraProfile, force: Bool = false) {
        let adjustedEV = measuredEV - profile.exposureCompensation

        // Debounce: skip if EV hasn't changed enough or too soon (unless forced by user action)
        let now = Date()
        if !force {
            let evDelta = abs(adjustedEV - lastRecommendationEV)
            let timeDelta = now.timeIntervalSince(lastRecommendationTime)
            if evDelta < recommendationThreshold && timeDelta < recommendationInterval {
                return
            }
        }
        lastRecommendationEV = adjustedEV
        lastRecommendationTime = now

        // Pinhole path: single fixed aperture, Schwarzschild correction
        if profile.type == .pinhole {
            isPinholeMode = true
            let result = ExposureCalculator.pinholeExposure(
                ev100: measuredEV,
                filmISO: profile.filmISO,
                pinholeAperture: profile.effectivePinholeAperture,
                compensation: profile.exposureCompensation,
                schwarzschildP: profile.schwarzschildP
            )
            recommendedAperture = profile.effectivePinholeAperture
            uncorrectedShutterSpeed = result.raw
            recommendedShutterSpeed = result.corrected
            exposureCombinations = []
            return
        }

        isPinholeMode = false
        uncorrectedShutterSpeed = 0

        let calibrate: (Double) -> Double = { profile.calibratedSpeed(for: $0) }

        switch meterMode {
        case .auto:
            let result = ExposureCalculator.bestExposure(
                ev100: measuredEV,
                filmISO: profile.filmISO,
                availableApertures: profile.activeApertures,
                availableShutterSpeeds: profile.sortedShutterSpeeds,
                compensation: profile.exposureCompensation,
                calibration: calibrate
            )
            recommendedAperture = result.aperture
            recommendedShutterSpeed = result.shutterSpeed

        case .aperturePriority:
            let locked = lockedAperture ?? profile.activeApertures.first ?? 5.6
            lockedAperture = locked
            recommendedAperture = locked
            let idealShutter = ExposureCalculator.shutterSpeed(
                forAperture: locked, ev100: adjustedEV, filmISO: profile.filmISO
            )
            recommendedShutterSpeed = ExposureCalculator.nearestValue(
                to: idealShutter, in: profile.sortedShutterSpeeds
            ) ?? idealShutter

        case .shutterPriority:
            let locked = lockedShutterSpeed ?? profile.sortedShutterSpeeds.first ?? (1.0 / 125)
            lockedShutterSpeed = locked
            recommendedShutterSpeed = locked
            let actualSpeed = calibrate(locked)
            let idealAperture = ExposureCalculator.aperture(
                forShutterSpeed: actualSpeed, ev100: adjustedEV, filmISO: profile.filmISO
            )
            recommendedAperture = ExposureCalculator.nearestValue(
                to: idealAperture, in: profile.activeApertures
            ) ?? idealAperture
        }

        exposureCombinations = ExposureCalculator.allCombinations(
            ev100: measuredEV,
            filmISO: profile.filmISO,
            availableApertures: profile.activeApertures,
            availableShutterSpeeds: profile.sortedShutterSpeeds,
            compensation: profile.exposureCompensation,
            calibration: calibrate
        )

        // Exposure status for priority modes: does the locked value have a valid combo?
        if meterMode != .auto {
            var lockedValueHasCombo = true

            switch meterMode {
            case .aperturePriority:
                if let locked = lockedAperture {
                    lockedValueHasCombo = exposureCombinations.contains { abs($0.aperture - locked) < 0.01 }
                }
            case .shutterPriority:
                if let locked = lockedShutterSpeed {
                    lockedValueHasCombo = exposureCombinations.contains {
                        locked > 0 && abs(log2($0.shutterSpeed) - log2(locked)) < 0.1
                    }
                }
            case .auto:
                break
            }

            if lockedValueHasCombo {
                exposureStatus = .correct
            } else {
                // Direction: compare recommended value to ideal value.
                // If recommended lets in less light than needed → underexposed.
                switch meterMode {
                case .aperturePriority:
                    // Free axis is shutter. Recommended snapped to nearest available.
                    // If recommended is faster (shorter) than ideal → less light → underexposed.
                    let idealShutter = ExposureCalculator.shutterSpeed(
                        forAperture: lockedAperture ?? 5.6, ev100: adjustedEV, filmISO: profile.filmISO
                    )
                    exposureStatus = recommendedShutterSpeed < idealShutter ? .underExposed : .overExposed
                case .shutterPriority:
                    // Free axis is aperture. Recommended snapped to nearest available.
                    // If recommended is narrower (larger f-number) than ideal → less light → underexposed.
                    let actualSpeed = calibrate(lockedShutterSpeed ?? (1.0 / 125))
                    let idealAperture = ExposureCalculator.aperture(
                        forShutterSpeed: actualSpeed, ev100: adjustedEV, filmISO: profile.filmISO
                    )
                    exposureStatus = recommendedAperture > idealAperture ? .underExposed : .overExposed
                default:
                    break
                }
            }
        } else {
            if exposureCombinations.isEmpty {
                // Determine direction: is the scene too bright or too dim for the equipment?
                let adjustedEV = measuredEV - profile.exposureCompensation
                let midAperture = profile.activeApertures.sorted()[profile.activeApertures.count / 2]
                let idealShutter = ExposureCalculator.shutterSpeed(
                    forAperture: midAperture, ev100: adjustedEV, filmISO: profile.filmISO
                )
                let fastest = profile.sortedShutterSpeeds.min() ?? (1.0 / 1000)
                exposureStatus = idealShutter < fastest ? .overExposed : .underExposed
            } else {
                exposureStatus = .correct
            }
        }
    }

    func toggleAperturePriority(currentAperture: Double) {
        if meterMode == .aperturePriority {
            meterMode = .auto
            lockedAperture = nil
        } else {
            meterMode = .aperturePriority
            lockedAperture = currentAperture
            lockedShutterSpeed = nil
        }
    }

    func toggleShutterPriority(currentShutter: Double) {
        if meterMode == .shutterPriority {
            meterMode = .auto
            lockedShutterSpeed = nil
        } else {
            meterMode = .shutterPriority
            lockedShutterSpeed = currentShutter
            lockedAperture = nil
        }
    }

    func setLockedAperture(_ value: Double) {
        lockedAperture = value
    }

    func setLockedShutterSpeed(_ value: Double) {
        lockedShutterSpeed = value
    }

    // MARK: - Focal Length Auto-Select

    func selectClosestCamera(toFocalLength targetMM: Int) {
        guard !availableCameras.isEmpty else { return }
        guard let closest = availableCameras.min(by: {
            abs($0.focalLength - targetMM) < abs($1.focalLength - targetMM)
        }), closest.id != activeCameraID else { return }
        switchCamera(to: closest)
    }

    // MARK: - Camera Discovery

    private func discoverCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )

        availableCameras = discovery.devices.map { device in
            let focal = Int(device.nominalFocalLengthIn35mmFilm)
            let label: String
            switch device.deviceType {
            case .builtInUltraWideCamera: label = "\(focal)mm"
            case .builtInTelephotoCamera: label = "\(focal)mm"
            default: label = "\(focal)mm"
            }
            return CameraLens(
                id: device.uniqueID,
                deviceType: device.deviceType,
                focalLength: focal,
                label: label
            )
        }

        // Default to wide-angle camera
        if activeCameraID.isEmpty, let wide = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            activeCameraID = wide.uniqueID
        }
    }

    func switchCamera(to lens: CameraLens) {
        guard lens.id != activeCameraID else { return }
        guard let session = captureSession else { return }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )

        guard let newDevice = discovery.devices.first(where: { $0.uniqueID == lens.id }) else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            session.beginConfiguration()

            // Remove old input
            if let oldInput = self.currentInput {
                session.removeInput(oldInput)
            }

            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.currentInput = newInput
                }

                try newDevice.lockForConfiguration()
                if newDevice.isExposureModeSupported(.continuousAutoExposure) {
                    newDevice.exposureMode = .continuousAutoExposure
                }
                if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                    newDevice.focusMode = .continuousAutoFocus
                }
                newDevice.unlockForConfiguration()
            } catch {
                // Switch failed
            }

            session.commitConfiguration()

            DispatchQueue.main.async {
                self.captureDevice = newDevice
                self.activeCameraID = lens.id
                self.observations.removeAll()
                self.hasInitialReading = false
                self.observeExposure()
            }
        }
    }

    // MARK: - Camera Session Setup

    private func setupSession() {
        guard captureSession == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Use the active camera (from discovery) or fall back to default
        let device: AVCaptureDevice?
        if !activeCameraID.isEmpty {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
                mediaType: .video,
                position: .back
            )
            device = discovery.devices.first(where: { $0.uniqueID == activeCameraID })
        } else {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }

        guard let device else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            self.currentInput = input

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: processingQueue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            try device.lockForConfiguration()
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            device.unlockForConfiguration()

            self.captureDevice = device
            self.captureSession = session
        } catch {
            // Camera setup failed
        }
    }

    // MARK: - Video Frame Processing

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Process every 3rd frame to save power
        frameSkipCounter += 1
        guard frameSkipCounter % 3 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Apply orientation so portrait frames are upright
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.right)

        // Crop to 3:2 landscape, downscale to 36x24 for a pixelated preview
        let extent = ciImage.extent
        let targetAspect: CGFloat = 3.0 / 2.0
        let cropW: CGFloat
        let cropH: CGFloat
        if extent.width / extent.height > targetAspect {
            cropH = extent.height
            cropW = cropH * targetAspect
        } else {
            cropW = extent.width
            cropH = cropW / targetAspect
        }
        let cropRect = CGRect(
            x: (extent.width - cropW) / 2,
            y: (extent.height - cropH) / 2,
            width: cropW,
            height: cropH
        )
        let cropped = ciImage.cropped(to: cropRect)
            .transformed(by: CGAffineTransform(
                translationX: -cropRect.origin.x,
                y: -cropRect.origin.y
            ))

        let targetW: CGFloat = 36
        let targetH: CGFloat = 24
        let scaleX = targetW / cropW
        let scaleY = targetH / cropH
        let scaled = cropped
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // High-contrast monochrome
        let mono = scaled
            .applyingFilter("CIPhotoEffectNoir")
            .applyingFilter("CIColorControls", parameters: [
                "inputContrast": 1.8,
                "inputBrightness": 0.1,
                "inputSaturation": 0.0
            ])

        let monoExtent = mono.extent
        guard let cgImage = ciContext.createCGImage(mono, from: monoExtent) else { return }

        // Build histogram from the scaled grayscale and smooth it
        let rawHistogram = self.buildHistogram(from: pixelBuffer)
        let alpha = self.histogramSmoothing
        var blended = self.smoothedHistogram
        for i in 0..<256 {
            blended[i] = blended[i] * (1 - alpha) + rawHistogram[i] * alpha
        }
        self.smoothedHistogram = blended

        DispatchQueue.main.async { [weak self] in
            self?.previewImage = cgImage
            self?.histogramBins = blended
        }
    }

    private func buildHistogram(from pixelBuffer: CVPixelBuffer) -> [Float] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Array(repeating: 0, count: 256)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)

        var bins = Array(repeating: 0, count: 256)
        let step = 8 // Sample every 8th pixel for performance

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                let b = Int(ptr[offset])
                let g = Int(ptr[offset + 1])
                let r = Int(ptr[offset + 2])
                // Luminance approximation
                let lum = (r * 77 + g * 150 + b * 29) >> 8
                bins[min(lum, 255)] += 1
            }
        }

        // Normalize to 0...1
        let maxVal = Float(bins.max() ?? 1)
        guard maxVal > 0 else { return Array(repeating: 0, count: 256) }
        return bins.map { Float($0) / maxVal }
    }

    // MARK: - KVO Observation

    private func observeExposure() {
        guard let device = captureDevice else { return }

        let durationObs = device.observe(\.exposureDuration, options: [.new]) { [weak self] dev, _ in
            let seconds = CMTimeGetSeconds(dev.exposureDuration)
            guard seconds > 0, seconds.isFinite else { return }
            DispatchQueue.main.async {
                self?.cameraExposureDuration = seconds
                self?.cameraISO = dev.iso
                self?.cameraAperture = dev.lensAperture
                self?.recalculateEV()
            }
        }

        let isoObs = device.observe(\.iso, options: [.new]) { [weak self] dev, _ in
            DispatchQueue.main.async {
                self?.cameraISO = dev.iso
                self?.recalculateEV()
            }
        }

        let offsetObs = device.observe(\.exposureTargetOffset, options: [.new]) { [weak self] dev, _ in
            DispatchQueue.main.async {
                self?.exposureTargetOffset = Double(dev.exposureTargetOffset)
                self?.recalculateEV()
            }
        }

        observations = [durationObs, isoObs, offsetObs]
    }

    // MARK: - EV Calculation

    private func recalculateEV() {
        guard cameraExposureDuration > 0, cameraISO > 0, cameraAperture > 0 else { return }

        var rawEV = ExposureCalculator.calculateEV100(
            aperture: Double(cameraAperture),
            shutterSpeed: cameraExposureDuration,
            iso: Double(cameraISO)
        )

        guard rawEV.isFinite else { return }

        // iPhone auto-exposure targets a brighter mid-tone than the
        // photographic standard (optimized for HDR/tone-mapped photos).
        // This systematic offset aligns readings with a handheld meter.
        rawEV -= 2.0

        // Determine device hardware limits from activeFormat
        let maxISO: Float
        let maxDuration: Double
        let minISO: Float
        if let format = captureDevice?.activeFormat {
            maxISO = format.maxISO
            maxDuration = CMTimeGetSeconds(format.maxExposureDuration)
            minISO = format.minISO
        } else {
            maxISO = 1500; maxDuration = 1.0 / 30.0; minISO = 20
        }

        // How close to limits (0 = comfortable, 1 = fully maxed)
        let isoRatio = Double(cameraISO) / Double(maxISO)
        let durationRatio = maxDuration > 0 ? cameraExposureDuration / maxDuration : 0
        let atLimit = max(isoRatio, durationRatio)

        // Low-light extension: apply exposureTargetOffset when camera is
        // near its hardware limits. The offset is the camera's own report
        // of how many stops underexposed the scene is.
        let offset = exposureTargetOffset
        if offset < -0.3, atLimit > 0.7 {
            rawEV += offset
        }

        // Update reliability based on actual device state
        let isoNearMin = Double(cameraISO) / Double(minISO) < 1.3
        let durationNearMin = cameraExposureDuration < 1.0 / 10000
        if isoNearMin && durationNearMin {
            meterReliability = .overExposed
        } else if atLimit > 0.85 {
            meterReliability = .lowLight
        } else {
            meterReliability = .normal
        }

        if !hasInitialReading {
            measuredEV = rawEV
            hasInitialReading = true
        } else {
            measuredEV = measuredEV + smoothingFactor * (rawEV - measuredEV)
        }
    }

    // MARK: - Simulator Fallback

    #if targetEnvironment(simulator)
    private func startSimulatorMetering() {
        isRunning = true
        permissionGranted = true
        hasInitialReading = true
        measuredEV = 12.0

        // Fake available cameras
        availableCameras = [
            CameraLens(id: "sim-ultra", deviceType: .builtInUltraWideCamera, focalLength: 13, label: "13mm"),
            CameraLens(id: "sim-wide", deviceType: .builtInWideAngleCamera, focalLength: 26, label: "26mm"),
            CameraLens(id: "sim-tele", deviceType: .builtInTelephotoCamera, focalLength: 77, label: "77mm"),
        ]
        activeCameraID = "sim-wide"

        // Generate a fake gradient preview image
        generateSimulatorPreview()

        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.simulatorPhase += 0.1
            let ev = 11.5 + 3.5 * sin(self.simulatorPhase)
            self.measuredEV = self.measuredEV + self.smoothingFactor * (ev - self.measuredEV)

            // Update fake histogram based on EV
            self.generateSimulatorHistogram(ev: self.measuredEV)
        }
    }

    private func generateSimulatorPreview() {
        let size = CGSize(width: 20, height: 15)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            let colors = [
                UIColor(white: 0.15, alpha: 1).cgColor,
                UIColor(white: 0.35, alpha: 1).cgColor,
                UIColor(white: 0.2, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: colors as CFArray,
                locations: [0, 0.5, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        previewImage = uiImage.cgImage
    }

    private func generateSimulatorHistogram(ev: Double) {
        // Generate a bell-curve-ish histogram shifted by EV
        let center = Int((ev / 16.0) * 255.0).clamped(to: 0...255)
        var bins = Array(repeating: Float(0), count: 256)
        let spread: Float = 40.0
        for i in 0..<256 {
            let dist = Float(i - center)
            bins[i] = exp(-(dist * dist) / (2.0 * spread * spread))
        }
        histogramBins = bins
    }
    #endif
}

// MARK: - Clamped helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
