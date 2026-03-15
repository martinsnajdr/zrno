import Foundation
import CoreMotion

/// Zrnoid – Arkanoid clone at 36x24 pixel resolution.
/// Paddle is controlled by device accelerometer (tilt left/right).
@MainActor @Observable
final class ArkanoidGame {
    // Grid
    let width = 36
    let height = 24

    // Paddle: bottom row, 5px wide
    private(set) var paddleX: Double = 18.0
    private let paddleW: Double = 5
    private let paddleRow = 23  // last row

    // Ball
    private(set) var ballX: Double = 18
    private(set) var ballY: Double = 19
    private var ballDX: Double = 0.0
    private var ballDY: Double = 0.0
    private let ballSpeed: Double = 0.30

    // Bricks: rows 0–4, each brick is 2px wide × 1px tall, edge to edge
    private(set) var bricks: Set<BrickPos> = []

    // State
    private(set) var isRunning = false
    private(set) var lives = 3
    private(set) var gameOver = false
    private(set) var won = false
    private(set) var score = 0
    private(set) var waitingToStart = true

    // High score
    static let highScoreKey = "zrno.zrnoid.highScore"
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Self.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.highScoreKey) }
    }

    private var gameTimer: Timer?
    private let motionManager = CMMotionManager()

    // Smoothed ball position for rendering (reduces jitter)
    private var displayBallX: Double = 18
    private var displayBallY: Double = 19

    // Ball trail — stores recent positions for ghost/trace effect
    private var ballTrail: [(x: Double, y: Double)] = []
    private let trailLength = 4

    // Smoothed paddle tilt (reduces accelerometer noise)
    private var smoothedTilt: Double = 0

    struct BrickPos: Hashable {
        let col: Int
        let row: Int
    }

    init() {
        resetBricks()
    }

    // MARK: - Setup

    private func resetBricks() {
        bricks.removeAll()
        // 5 rows (0–4), 18 bricks per row (36 cols / 2), edge to edge
        for row in 0...4 {
            for brickIdx in 0..<18 {
                let col = brickIdx * 2
                bricks.insert(BrickPos(col: col, row: row))
                bricks.insert(BrickPos(col: col + 1, row: row))
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        gameOver = false
        won = false
        waitingToStart = true
        lives = 3
        score = 0
        resetBricks()
        paddleX = Double(width) / 2.0
        smoothedTilt = 0
        resetBall()
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

    private func resetBall() {
        ballX = Double(width) / 2.0
        ballY = Double(paddleRow) - 2.0
        displayBallX = ballX
        displayBallY = ballY
        ballTrail.removeAll()
        let angle = Double.random(in: 0.5...1.1)
        let dir: Double = Bool.random() ? 1.0 : -1.0
        ballDX = dir * cos(angle) * ballSpeed
        ballDY = -sin(angle) * ballSpeed
    }

    // MARK: - Accelerometer

    private func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates()
    }

    // MARK: - Game Loop

    private func tick() {
        guard isRunning, !gameOver, !won else { return }

        // Read accelerometer for paddle (smoothed to reduce jitter)
        if let data = motionManager.accelerometerData {
            let rawTilt = data.acceleration.x
            smoothedTilt += (rawTilt - smoothedTilt) * 0.3
            paddleX += smoothedTilt * 2.2
            paddleX = max(paddleW / 2.0, min(Double(width) - paddleW / 2.0, paddleX))
        }

        // If waiting to start, ball follows paddle (centered)
        if waitingToStart {
            ballX = paddleX
            ballY = Double(paddleRow) - 2.0
            displayBallX = ballX
            displayBallY = ballY
            return
        }

        // Move ball with sub-steps
        let steps = 4
        let stepDX = ballDX / Double(steps)
        let stepDY = ballDY / Double(steps)

        for _ in 0..<steps {
            let newX = ballX + stepDX
            let newY = ballY + stepDY

            if newX < 0.5 {
                ballDX = abs(ballDX)
                ballX = 0.5
                continue
            }
            if newX > Double(width) - 0.5 {
                ballDX = -abs(ballDX)
                ballX = Double(width) - 0.5
                continue
            }
            if newY < 0.5 {
                ballDY = abs(ballDY)
                ballY = 0.5
                continue
            }

            // Paddle collision
            let paddleTop = Double(paddleRow) - 0.5
            if ballY <= paddleTop && newY > paddleTop && ballDY > 0 {
                let paddleLeft = paddleX - paddleW / 2.0
                let paddleRight = paddleX + paddleW / 2.0
                if newX >= paddleLeft - 0.3 && newX <= paddleRight + 0.3 {
                    ballDY = -abs(ballDY)
                    ballY = paddleTop - 0.1
                    let hitPos = (newX - paddleLeft) / paddleW
                    ballDX = (hitPos - 0.5) * 1.0
                    let spd = sqrt(ballDX * ballDX + ballDY * ballDY)
                    if spd > 0 {
                        ballDX = ballDX / spd * ballSpeed
                        ballDY = ballDY / spd * ballSpeed
                    }
                    continue
                }
            }

            // Ball lost
            if newY >= Double(height) + 0.5 {
                lives -= 1
                if lives <= 0 {
                    gameOver = true
                    if score > highScore { highScore = score }
                }
                resetBall()
                waitingToStart = true
                return
            }

            // Brick collision
            let checkCol = Int(newX)
            let checkRow = Int(newY)
            let brick = BrickPos(col: checkCol, row: checkRow)
            if bricks.contains(brick) {
                let baseCol = (checkCol / 2) * 2
                bricks.remove(BrickPos(col: baseCol, row: checkRow))
                bricks.remove(BrickPos(col: baseCol + 1, row: checkRow))
                score += 1
                ballDY = -ballDY

                if bricks.isEmpty {
                    won = true
                    if score > highScore { highScore = score }
                    return
                }
                continue
            }

            ballX = newX
            ballY = newY
        }

        // Smooth display position — high factor tracks closely, filters sub-pixel noise
        let smoothing = 0.8
        displayBallX = displayBallX + (ballX - displayBallX) * smoothing
        displayBallY = displayBallY + (ballY - displayBallY) * smoothing

        // Record trail
        ballTrail.append((x: displayBallX, y: displayBallY))
        if ballTrail.count > trailLength {
            ballTrail.removeFirst(ballTrail.count - trailLength)
        }
    }

    /// Called by tap to launch ball or restart
    func handleTap() {
        if gameOver || won {
            restart()
        } else if waitingToStart {
            waitingToStart = false
        }
    }

    func restart() {
        stop()
        start()
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

        // Trail-safe: only writes over background pixels, never over content
        func setPixelIfBg(_ col: Int, _ row: Int, r: UInt8, g: UInt8, b: UInt8) {
            guard col >= 0, col < width, row >= 0, row < height else { return }
            let offset = (row * width + col) * 4
            // Only draw if the pixel is still the background color
            if pixels[offset] == bgR && pixels[offset+1] == bgG && pixels[offset+2] == bgB {
                pixels[offset] = r; pixels[offset+1] = g; pixels[offset+2] = b
            }
        }

        let dimR = UInt8(clamping: Int(Double(bgR) * 0.5 + Double(fgR) * 0.5))
        let dimG = UInt8(clamping: Int(Double(bgG) * 0.5 + Double(fgG) * 0.5))
        let dimB = UInt8(clamping: Int(Double(bgB) * 0.5 + Double(fgB) * 0.5))

        // Draw bricks
        for brick in bricks {
            let rowFade = Double(5 - brick.row) / 4.0
            let opacity = 0.4 + 0.6 * rowFade
            let r = UInt8(clamping: Int(Double(bgR) * (1 - opacity) + Double(fgR) * opacity))
            let g = UInt8(clamping: Int(Double(bgG) * (1 - opacity) + Double(fgG) * opacity))
            let b = UInt8(clamping: Int(Double(bgB) * (1 - opacity) + Double(fgB) * opacity))
            setPixel(brick.col, brick.row, r: r, g: g, b: b)
        }

        // Draw paddle
        let paddleLeft = Int(round(paddleX - paddleW / 2.0))
        for col in paddleLeft..<(paddleLeft + Int(paddleW)) {
            setPixel(col, paddleRow, r: fgR, g: fgG, b: fgB)
        }

        // Draw soft trail — each past position plus cross neighbours, only over background
        let ballCol = Int(round(displayBallX))
        let ballRow = Int(round(displayBallY))
        for (i, pos) in ballTrail.enumerated() {
            let age = Double(ballTrail.count - i)
            let centerFade = max(0.03, 0.12 - age * 0.025)
            let neighbourFade = centerFade * 0.45
            let tc = Int(round(pos.x))
            let tr = Int(round(pos.y))
            if tc != ballCol || tr != ballRow {
                let cr = UInt8(clamping: Int(Double(bgR) * (1 - centerFade) + Double(fgR) * centerFade))
                let cg = UInt8(clamping: Int(Double(bgG) * (1 - centerFade) + Double(fgG) * centerFade))
                let cb = UInt8(clamping: Int(Double(bgB) * (1 - centerFade) + Double(fgB) * centerFade))
                setPixelIfBg(tc, tr, r: cr, g: cg, b: cb)
            }
            let nr = UInt8(clamping: Int(Double(bgR) * (1 - neighbourFade) + Double(fgR) * neighbourFade))
            let ng = UInt8(clamping: Int(Double(bgG) * (1 - neighbourFade) + Double(fgG) * neighbourFade))
            let nb = UInt8(clamping: Int(Double(bgB) * (1 - neighbourFade) + Double(fgB) * neighbourFade))
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = tc + dx, ny = tr + dy
                if nx != ballCol || ny != ballRow {
                    setPixelIfBg(nx, ny, r: nr, g: ng, b: nb)
                }
            }
        }

        // Ball pixel (full brightness, on top)
        setPixel(ballCol, ballRow, r: fgR, g: fgG, b: fgB)

        // Draw lives as tiny hearts (3x2 each) in top-right area, row 0–1
        //  row0: X.X
        //  row1: .X.
        for i in 0..<lives {
            let baseCol = width - 4 - i * 4
            setPixel(baseCol, 0, r: dimR, g: dimG, b: dimB)
            setPixel(baseCol + 2, 0, r: dimR, g: dimG, b: dimB)
            setPixel(baseCol + 1, 1, r: dimR, g: dimG, b: dimB)
        }

        // Score top-left as number text
        drawScore(score, startCol: 1, row: 0, &pixels, fgR: dimR, fgG: dimG, fgB: dimB)

        // Pixelated text overlay — "TAP" centered at row 10 (vertically centered in 24px grid with 4px tall text)
        if waitingToStart || gameOver || won {
            drawText("TAP", centerRow: 10, &pixels, fgR: fgR, fgG: fgG, fgB: fgB)
        }

        return pixels
    }

    // MARK: - Pixel Font

    /// Draws 3-letter text centered horizontally. Each char is 3x4 pixels.
    private func drawText(_ text: String, centerRow: Int, _ pixels: inout [UInt8],
                          fgR: UInt8, fgG: UInt8, fgB: UInt8) {
        let chars = Array(text)
        let charW = 3
        let charH = 4
        let spacing = 1
        let totalW = chars.count * charW + (chars.count - 1) * spacing
        let startCol = (width - totalW) / 2

        for (i, ch) in chars.enumerated() {
            let bitmap = pixelFont(ch)
            let colOffset = startCol + i * (charW + spacing)
            for row in 0..<charH {
                for col in 0..<charW {
                    if bitmap[row * charW + col] == 1 {
                        let px = colOffset + col
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
