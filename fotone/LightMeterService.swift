import AVFoundation
import CoreImage
import Observation
import UIKit

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

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var observations: [NSKeyValueObservation] = []
    private let sessionQueue = DispatchQueue(label: "com.svit.session")
    private let processingQueue = DispatchQueue(label: "com.svit.processing", qos: .userInitiated)
    private let smoothingFactor: Double = 0.15
    private var hasInitialReading = false
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var frameSkipCounter = 0

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

    func updateRecommendation(for profile: CameraProfile) {
        let result = ExposureCalculator.bestExposure(
            ev100: measuredEV,
            filmISO: profile.filmISO,
            availableApertures: profile.sortedApertures,
            availableShutterSpeeds: profile.sortedShutterSpeeds,
            compensation: profile.exposureCompensation
        )
        recommendedAperture = result.aperture
        recommendedShutterSpeed = result.shutterSpeed

        exposureCombinations = ExposureCalculator.allCombinations(
            ev100: measuredEV,
            filmISO: profile.filmISO,
            availableApertures: profile.sortedApertures,
            availableShutterSpeeds: profile.sortedShutterSpeeds,
            compensation: profile.exposureCompensation
        )
    }

    // MARK: - Camera Session Setup

    private func setupSession() {
        guard captureSession == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

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
        MainActor.assumeIsolated {
            frameSkipCounter += 1
        }
        // Use a simple counter approach — not perfectly thread-safe but fine for skip logic
        guard frameSkipCounter % 3 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Downscale + monochrome for the lo-fi preview
        let scale: CGFloat = 0.15
        let scaled = ciImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let mono = scaled
            .applyingFilter("CIColorMonochrome", parameters: [
                "inputColor": CIColor(red: 0.9, green: 0.9, blue: 0.85),
                "inputIntensity": 1.0
            ])
            .applyingFilter("CIColorControls", parameters: [
                "inputContrast": 1.3,
                "inputBrightness": -0.05
            ])

        let extent = mono.extent
        guard let cgImage = ciContext.createCGImage(mono, from: extent) else { return }

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
        let size = CGSize(width: 120, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            // Dark gradient simulating a scene
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
