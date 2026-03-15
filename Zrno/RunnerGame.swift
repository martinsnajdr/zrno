import Foundation
import CoreMotion

/// Zrnorun – Endless runner at 36x24 pixel resolution.
/// A photographer character runs and jumps over obstacles.
/// Jump is triggered by tilting the phone upward (accelerometer Z spike).
@MainActor @Observable
final class RunnerGame {
    let width = 36
    let height = 24

    // Ground
    private let groundY = 19  // feet land on this row
    private let runnerCol = 5

    // Photographer sprite (6 px tall × 5 px wide):
    //  row 0: ...X.  (camera top)
    //  row 1: ..XXX  (camera body + arm)
    //  row 2: .XX..  (head)
    //  row 3: XXX..  (torso + back arm)
    //  row 4: .XX..  (hips)
    //  row 5: .X.X.  (legs, animated)
    private let spriteH = 6
    private let spriteW = 5

    // Physics
    private(set) var runnerY: Double
    private var velocityY: Double = 0
    private var isOnGround: Bool { runnerY >= Double(groundY) }
    private let gravity: Double = 0.14
    private let jumpForce: Double = -1.8

    // Animation
    private var frameTick = 0
    private var legFrame = 0

    // Ground scroll offset (only moves when game is running)
    private var groundOffset: Double = 0

    // Obstacles
    private(set) var obstacles: [(x: Double, h: Int, scored: Bool)] = []
    private var nextObstacleDistance: Double = 0
    private let scrollSpeed: Double = 0.5
    private var speedMultiplier: Double = 1.0

    // State
    private(set) var isRunning = false
    private(set) var gameOver = false
    private(set) var score = 0
    private(set) var waitingToStart = true

    // High score
    static let highScoreKey = "zrno.zrnorun.highScore"
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Self.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.highScoreKey) }
    }

    private var gameTimer: Timer?
    private let motionManager = CMMotionManager()
    private var lastAccelZ: Double = 0
    private var jumpCooldown = 0

    init() {
        runnerY = Double(groundY)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        gameOver = false
        waitingToStart = true
        score = 0
        speedMultiplier = 1.0
        runnerY = Double(groundY)
        velocityY = 0
        obstacles.removeAll()
        nextObstacleDistance = 25
        frameTick = 0
        jumpCooldown = 0
        groundOffset = 0
        startAccelerometer()
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stop() {
        isRunning = false
        gameTimer?.invalidate()
        gameTimer = nil
        motionManager.stopAccelerometerUpdates()
    }

    func restart() { stop(); start() }

    /// Tap to start, jump, or restart
    func handleTap() {
        if gameOver {
            restart()
        } else if waitingToStart {
            waitingToStart = false
        } else if isOnGround && jumpCooldown == 0 {
            velocityY = jumpForce
            jumpCooldown = 5
        }
    }

    // MARK: - Accelerometer

    private func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates()
    }

    // MARK: - Game Loop

    private func tick() {
        guard isRunning, !gameOver else { return }

        frameTick += 1
        if jumpCooldown > 0 { jumpCooldown -= 1 }

        // Jump via accelerometer
        if let data = motionManager.accelerometerData {
            let accelZ = data.acceleration.z
            let delta = accelZ - lastAccelZ
            if delta > 0.3 && isOnGround && jumpCooldown == 0 && !waitingToStart {
                velocityY = jumpForce
                jumpCooldown = 5
            }
            lastAccelZ = accelZ
        }

        // Nothing moves until game starts
        if waitingToStart { return }

        // Physics — also enter when velocity is negative (jumping up from ground)
        if !isOnGround || velocityY < 0 {
            velocityY += gravity
            runnerY += velocityY
            if runnerY >= Double(groundY) {
                runnerY = Double(groundY)
                velocityY = 0
            }
        }

        // Legs animation
        if isOnGround && frameTick % 4 == 0 {
            legFrame = (legFrame + 1) % 3
        }

        // Scroll
        let spd = scrollSpeed * speedMultiplier
        groundOffset += spd
        for i in obstacles.indices { obstacles[i].x -= spd }
        obstacles.removeAll { $0.x < -3 }

        // Spawn
        nextObstacleDistance -= spd
        if nextObstacleDistance <= 0 {
            let h = Int.random(in: 1...3)
            obstacles.append((x: Double(width + 1), h: h, scored: false))
            nextObstacleDistance = Double.random(in: 18...30)
        }

        // Score: +1 for each obstacle the runner passes
        for i in obstacles.indices {
            if !obstacles[i].scored && Int(round(obstacles[i].x)) + 1 < runnerCol {
                obstacles[i].scored = true
                score += 1
            }
        }

        if frameTick % 300 == 0 { speedMultiplier += 0.06 }

        // Collision
        let feetRow = Int(round(runnerY))
        let topRow = feetRow - (spriteH - 1)
        let left = runnerCol
        let right = runnerCol + spriteW - 1

        for obs in obstacles {
            let obsCol = Int(round(obs.x))
            let obsTop = groundY + 1 - obs.h
            let obsBottom = groundY
            let obsRight = obsCol + 1

            if right >= obsCol && left <= obsRight &&
               feetRow >= obsTop && topRow <= obsBottom {
                gameOver = true
                if score > highScore { highScore = score }
                return
            }
        }
    }

    // MARK: - Render

    func render(fgR: UInt8, fgG: UInt8, fgB: UInt8,
                bgR: UInt8, bgG: UInt8, bgB: UInt8) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let offset = i * 4
            pixels[offset] = bgR; pixels[offset+1] = bgG; pixels[offset+2] = bgB; pixels[offset+3] = 255
        }

        func setPixel(_ col: Int, _ row: Int, r: UInt8, g: UInt8, b: UInt8) {
            guard col >= 0, col < width, row >= 0, row < height else { return }
            let offset = (row * width + col) * 4
            pixels[offset] = r; pixels[offset+1] = g; pixels[offset+2] = b; pixels[offset+3] = 255
        }

        let dimR = UInt8(clamping: Int(Double(bgR) * 0.6 + Double(fgR) * 0.4))
        let dimG = UInt8(clamping: Int(Double(bgG) * 0.6 + Double(fgG) * 0.4))
        let dimB = UInt8(clamping: Int(Double(bgB) * 0.6 + Double(fgB) * 0.4))

        // Ground line
        for col in 0..<width {
            setPixel(col, groundY + 1, r: dimR, g: dimG, b: dimB)
        }

        // Ground texture (sparse dots, scroll only when running)
        let scrollOff = Int(groundOffset) % 4
        for col in stride(from: (4 - scrollOff) % 4, to: width, by: 4) {
            setPixel(col, groundY + 2, r: dimR, g: dimG, b: dimB)
        }

        // Photographer sprite (6 tall × 5 wide)
        let feetRow = Int(round(runnerY))
        let c = runnerCol

        // Row 0 (top): camera viewfinder   ...X.
        setPixel(c + 3, feetRow - 5, r: fgR, g: fgG, b: fgB)

        // Row 1: camera body + arm          ..XXX
        setPixel(c + 2, feetRow - 4, r: fgR, g: fgG, b: fgB)
        setPixel(c + 3, feetRow - 4, r: fgR, g: fgG, b: fgB)
        setPixel(c + 4, feetRow - 4, r: fgR, g: fgG, b: fgB)

        // Row 2: head                       .XX..
        setPixel(c + 1, feetRow - 3, r: fgR, g: fgG, b: fgB)
        setPixel(c + 2, feetRow - 3, r: fgR, g: fgG, b: fgB)

        // Row 3: torso + back arm           XXX..
        setPixel(c, feetRow - 2, r: fgR, g: fgG, b: fgB)
        setPixel(c + 1, feetRow - 2, r: fgR, g: fgG, b: fgB)
        setPixel(c + 2, feetRow - 2, r: fgR, g: fgG, b: fgB)

        // Row 4: hips                       .XX..
        setPixel(c + 1, feetRow - 1, r: fgR, g: fgG, b: fgB)
        setPixel(c + 2, feetRow - 1, r: fgR, g: fgG, b: fgB)

        // Row 5: legs (animated, 3 frames)
        if isOnGround {
            switch legFrame {
            case 0:
                // X...X (legs apart)
                setPixel(c, feetRow, r: fgR, g: fgG, b: fgB)
                setPixel(c + 3, feetRow, r: fgR, g: fgG, b: fgB)
            case 1:
                // .X.X. (mid-stride)
                setPixel(c + 1, feetRow, r: fgR, g: fgG, b: fgB)
                setPixel(c + 3, feetRow, r: fgR, g: fgG, b: fgB)
            default:
                // .XX.. (legs together)
                setPixel(c + 1, feetRow, r: fgR, g: fgG, b: fgB)
                setPixel(c + 2, feetRow, r: fgR, g: fgG, b: fgB)
            }
        } else {
            // In air: legs tucked  .XX..
            setPixel(c + 1, feetRow, r: fgR, g: fgG, b: fgB)
            setPixel(c + 2, feetRow, r: fgR, g: fgG, b: fgB)
        }

        // Obstacles
        for obs in obstacles {
            let obsCol = Int(round(obs.x))
            for h in 0..<obs.h {
                let row = groundY - h
                setPixel(obsCol, row, r: fgR, g: fgG, b: fgB)
                setPixel(obsCol + 1, row, r: fgR, g: fgG, b: fgB)
            }
        }

        // Score top-left as number text
        drawScore(score, startCol: 1, row: 0, &pixels, fgR: dimR, fgG: dimG, fgB: dimB)

        // Pixelated text overlay — "TAP" centered at row 10
        if waitingToStart || gameOver {
            drawText("TAP", centerRow: 10, &pixels, fgR: fgR, fgG: fgG, fgB: fgB)
        }

        return pixels
    }

    // MARK: - Pixel Font

    private func drawText(_ text: String, centerRow: Int, _ pixels: inout [UInt8],
                          fgR: UInt8, fgG: UInt8, fgB: UInt8) {
        let chars = Array(text)
        let charW = 3; let charH = 4; let spacing = 1
        let totalW = chars.count * charW + (chars.count - 1) * spacing
        let startCol = (width - totalW) / 2

        for (i, ch) in chars.enumerated() {
            let bitmap = pixelFont(ch)
            let colOff = startCol + i * (charW + spacing)
            for row in 0..<charH {
                for col in 0..<charW {
                    if bitmap[row * charW + col] == 1 {
                        let px = colOff + col
                        let py = centerRow + row
                        guard px >= 0, px < width, py >= 0, py < height else { continue }
                        let offset = (py * width + px) * 4
                        pixels[offset] = fgR; pixels[offset+1] = fgG; pixels[offset+2] = fgB; pixels[offset+3] = 255
                    }
                }
            }
        }
    }

    /// Draws a numeric score at given position using 3x5 digit font
    private func drawScore(_ value: Int, startCol: Int, row: Int, _ pixels: inout [UInt8],
                           fgR: UInt8, fgG: UInt8, fgB: UInt8) {
        let digits = String(value)
        let charW = 3
        let charH = 5
        var col = startCol
        for ch in digits {
            let bitmap = scoreFont(ch)
            for r in 0..<charH {
                for c in 0..<charW {
                    if bitmap[r * charW + c] == 1 {
                        let px = col + c
                        let py = row + r
                        guard px >= 0, px < width, py >= 0, py < height else { continue }
                        let offset = (py * width + px) * 4
                        pixels[offset] = fgR; pixels[offset+1] = fgG; pixels[offset+2] = fgB; pixels[offset+3] = 255
                    }
                }
            }
            col += charW + 1
        }
    }

    /// 3x4 pixel font for uppercase letters used in text overlays.
    private func pixelFont(_ ch: Character) -> [Int] {
        switch ch {
        case "T": return [1,1,1, 0,1,0, 0,1,0, 0,1,0]
        case "A": return [0,1,0, 1,0,1, 1,1,1, 1,0,1]
        case "P": return [1,1,0, 1,0,1, 1,1,0, 1,0,0]
        default:  return [0,0,0, 0,0,0, 0,0,0, 0,0,0]
        }
    }

    /// 3x5 pixel font for digits used in score display.
    private func scoreFont(_ ch: Character) -> [Int] {
        switch ch {
        case "0": return [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1]
        case "1": return [0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1]
        case "2": return [1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1]
        case "3": return [1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1]
        case "4": return [1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1]
        case "5": return [1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1]
        case "6": return [1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1]
        case "7": return [1,1,1, 0,0,1, 0,1,0, 0,1,0, 0,1,0]
        case "8": return [1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1]
        case "9": return [1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1]
        default:  return [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0]
        }
    }
}
