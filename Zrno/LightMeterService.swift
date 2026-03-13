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

    // Multi-camera
    var availableCameras: [CameraLens] = []
    var activeCameraID: String = ""

    // Focus distance (0.0 = near, 1.0 = far)
    var focusPosition: Float = 1.0

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
        observeFocus()
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
            // Use calibrated speed for the calculation
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
            // Use the calibrated actual speed for aperture calculation
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
                self.observeFocus()
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

        // Crop to 4:3 landscape, downscale to 64x48 for a pixelated preview
        let extent = ciImage.extent
        let targetAspect: CGFloat = 4.0 / 3.0
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

        let targetW: CGFloat = 64
        let targetH: CGFloat = 48
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

        // Build histogram from the scaled grayscale
        let histogram = self.buildHistogram(from: pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            self?.previewImage = cgImage
            self?.histogramBins = histogram
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

        observations = [durationObs, isoObs]
    }

    // MARK: - Focus Observation

    private func observeFocus() {
        guard let device = captureDevice else { return }

        let focusObs = device.observe(\.lensPosition, options: [.new]) { [weak self] dev, _ in
            DispatchQueue.main.async {
                self?.focusPosition = dev.lensPosition
            }
        }
        observations.append(focusObs)
    }

    // MARK: - EV Calculation

    private func recalculateEV() {
        guard cameraExposureDuration > 0, cameraISO > 0, cameraAperture > 0 else { return }

        let rawEV = ExposureCalculator.calculateEV100(
            aperture: Double(cameraAperture),
            shutterSpeed: cameraExposureDuration,
            iso: Double(cameraISO)
        )

        guard rawEV.isFinite else { return }

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

            // Fake oscillating focus position
            self.focusPosition = Float(0.5 + 0.4 * sin(self.simulatorPhase * 0.7))

            // Update fake histogram based on EV
            self.generateSimulatorHistogram(ev: self.measuredEV)
        }
    }

    private func generateSimulatorPreview() {
        let size = CGSize(width: 64, height: 48)
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
