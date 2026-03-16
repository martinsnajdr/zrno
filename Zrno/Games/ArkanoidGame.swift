import Foundation
import CoreMotion
import UIKit

/// Zrnoid – Arkanoid clone at 36×24 pixel resolution.
/// Rendered at 4x (144×96) so ball and paddle move at sub-game-pixel precision.
/// Internal 30fps Timer drives the game loop.
/// Paddle is controlled by device accelerometer (tilt left/right).
@MainActor @Observable
final class ArkanoidGame {

    // MARK: - Constants

    let width = 36
    let height = 24
    private let paddleW: Double = 5
    private let paddleRow = 23
    private let ballSpeed: Double = 0.75  // game pixels per tick at 30fps

    // MARK: - Paddle

    private(set) var paddleX: Double = 18.0  // center position
    private var smoothedTilt: Double = 0

    // MARK: - Ball (floating-point, top-left corner of 1×1 game-pixel ball)

    private(set) var ballX: Double = 18
    private(set) var ballY: Double = 19
    private var ballDX: Double = 0
    private var ballDY: Double = 0

    // MARK: - Bricks

    struct BrickPos: Hashable { let col: Int; let row: Int }
    private(set) var bricks: Set<BrickPos> = []

    // MARK: - State

    private(set) var isRunning = false
    private(set) var lives = 3
    private(set) var gameOver = false
    private(set) var won = false
    private(set) var score = 0
    private(set) var waitingToStart = true

    static let highScoreKey = "zrno.zrnoid.highScore"
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Self.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.highScoreKey) }
    }

    // MARK: - Haptics

    private let paddleHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let brickHaptic = UIImpactFeedbackGenerator(style: .light)
    private let wallHaptic = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Timing

    private var gameTimer: Timer?
    private let motionManager = CMMotionManager()

    // MARK: - Render

    let scale = 4
    var renderWidth: Int { width * scale }   // 144
    var renderHeight: Int { height * scale }  // 96

    // MARK: - Init

    init() { resetBricks() }

    // MARK: - Setup

    private func resetBricks() {
        bricks.removeAll()
        for row in 0...4 {
            for i in 0..<18 {
                let col = i * 2
                bricks.insert(BrickPos(col: col, row: row))
                bricks.insert(BrickPos(col: col + 1, row: row))
            }
        }
    }

    private func resetBall() {
        ballX = Double(width) / 2.0 - 0.5  // center the ball
        ballY = Double(paddleRow) - 2.0
        let angle = Double.random(in: 0.5...1.1)
        let dir: Double = Bool.random() ? 1.0 : -1.0
        ballDX = dir * cos(angle) * ballSpeed
        ballDY = -sin(angle) * ballSpeed
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        gameOver = false
        won = false
        waitingToStart = true
        lives = 3
        score = 0
        smoothedTilt = 0
        paddleX = Double(width) / 2.0
        resetBricks()
        resetBall()
        startAccelerometer()
        paddleHaptic.prepare()
        brickHaptic.prepare()
        wallHaptic.prepare()
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
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

    func handleTap() {
        if gameOver || won {
            restart()
            waitingToStart = false
        } else if waitingToStart {
            waitingToStart = false
        }
    }

    // MARK: - Accelerometer

    private func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
        motionManager.startAccelerometerUpdates()
    }

    // MARK: - Game Loop (30fps)

    private func tick() {
        guard isRunning, !gameOver, !won else { return }

        // Paddle
        if let data = motionManager.accelerometerData {
            smoothedTilt += (data.acceleration.x - smoothedTilt) * 0.3
            paddleX += smoothedTilt * 3.3
            let halfP = paddleW / 2
            paddleX = max(halfP, min(Double(width) - halfP, paddleX))
        }

        if waitingToStart {
            ballX = paddleX - 0.5
            ballY = Double(paddleRow) - 2.0
            return
        }

        // Move ball
        var newX = ballX + ballDX
        var newY = ballY + ballDY

        // Ball occupies [newX, newX+1) × [newY, newY+1) in game space
        let ballSize = 1.0

        // Left wall: ball left edge must stay >= 0
        if newX < 0 {
            newX = -newX
            ballDX = abs(ballDX)
            wallHaptic.impactOccurred(intensity: 0.3)
        }
        // Right wall: ball right edge must stay <= width
        if newX + ballSize > Double(width) {
            newX = Double(width) - ballSize - (newX + ballSize - Double(width))
            ballDX = -abs(ballDX)
            wallHaptic.impactOccurred(intensity: 0.3)
        }
        // Top wall: ball top edge must stay >= 0
        if newY < 0 {
            newY = -newY
            ballDY = abs(ballDY)
            wallHaptic.impactOccurred(intensity: 0.3)
        }

        // Paddle collision: ball bottom edge crosses paddle top
        let ballBottom = newY + ballSize
        let paddleTop = Double(paddleRow)
        let prevBottom = ballY + ballSize
        if prevBottom <= paddleTop && ballBottom > paddleTop && ballDY > 0 {
            let pL = paddleX - paddleW / 2
            let pR = paddleX + paddleW / 2
            let ballCenterX = newX + 0.5
            if ballCenterX >= pL - 0.5 && ballCenterX <= pR + 0.5 {
                newY = paddleTop - ballSize  // place ball just above paddle
                let hitPos = (ballCenterX - pL) / paddleW  // 0..1
                ballDX = (hitPos - 0.5) * 2.0
                ballDY = -abs(ballDY)
                // Normalize to constant speed
                let spd = sqrt(ballDX * ballDX + ballDY * ballDY)
                if spd > 0 {
                    ballDX = ballDX / spd * ballSpeed
                    ballDY = ballDY / spd * ballSpeed
                }
                paddleHaptic.impactOccurred(intensity: 0.6)
            }
        }

        ballX = newX
        ballY = newY

        // Ball lost: ball top edge goes below screen
        if ballY > Double(height) {
            lives -= 1
            if lives <= 0 { gameOver = true; if score > highScore { highScore = score } }
            resetBall()
            waitingToStart = true
            paddleHaptic.impactOccurred(intensity: 1.0)
            return
        }

        // Brick collision: check all 4 corners of the ball
        let corners = [
            (Int(floor(ballX)), Int(floor(ballY))),               // top-left
            (Int(floor(ballX + ballSize - 0.01)), Int(floor(ballY))),       // top-right
            (Int(floor(ballX)), Int(floor(ballY + ballSize - 0.01))),       // bottom-left
            (Int(floor(ballX + ballSize - 0.01)), Int(floor(ballY + ballSize - 0.01)))  // bottom-right
        ]
        var hitBrick = false
        for (col, row) in corners {
            if col >= 0 && col < width && row >= 0 && row < height &&
               bricks.contains(BrickPos(col: col, row: row)) {
                let base = (col / 2) * 2
                bricks.remove(BrickPos(col: base, row: row))
                bricks.remove(BrickPos(col: base + 1, row: row))
                score += 1
                hitBrick = true
            }
        }
        if hitBrick {
            ballDY = -ballDY
            brickHaptic.impactOccurred(intensity: 0.4)
            if bricks.isEmpty { won = true; if score > highScore { highScore = score } }
        }
    }

    // MARK: - Render (4x resolution: 144×96 output, pre-allocated buffer)

    func render(fgR: UInt8, fgG: UInt8, fgB: UInt8,
                bgR: UInt8, bgG: UInt8, bgB: UInt8) -> [UInt8] {
        let rw = renderWidth, rh = renderHeight
        let s = scale

        // Allocate fresh buffer — at 144×96 (55KB) this is cheap
        var px = [UInt8](repeating: 0, count: rw * rh * 4)
        for i in 0..<(rw * rh) {
            let o = i * 4
            px[o] = bgR; px[o+1] = bgG; px[o+2] = bgB; px[o+3] = 255
        }

        // Fill a game-grid cell (scale×scale block)
        func setCell(_ c: Int, _ r: Int, _ cr: UInt8, _ cg: UInt8, _ cb: UInt8) {
            guard c >= 0, c < width, r >= 0, r < height else { return }
            let sx = c * s, sy = r * s
            for dy in 0..<s { for dx in 0..<s {
                let o = ((sy + dy) * rw + sx + dx) * 4
                px[o] = cr; px[o+1] = cg; px[o+2] = cb
            }}
        }

        // Set a single render pixel
        func setPixel(_ x: Int, _ y: Int, _ cr: UInt8, _ cg: UInt8, _ cb: UInt8) {
            guard x >= 0, x < rw, y >= 0, y < rh else { return }
            let o = (y * rw + x) * 4
            px[o] = cr; px[o+1] = cg; px[o+2] = cb
        }

        let dimR = UInt8(clamping: (Int(bgR) + Int(fgR)) / 2)
        let dimG = UInt8(clamping: (Int(bgG) + Int(fgG)) / 2)
        let dimB = UInt8(clamping: (Int(bgB) + Int(fgB)) / 2)

        // Bricks
        for b in bricks {
            let t = 0.4 + 0.6 * Double(5 - b.row) / 4.0
            let r = UInt8(clamping: Int(Double(bgR) * (1 - t) + Double(fgR) * t))
            let g = UInt8(clamping: Int(Double(bgG) * (1 - t) + Double(fgG) * t))
            let bl = UInt8(clamping: Int(Double(bgB) * (1 - t) + Double(fgB) * t))
            setCell(b.col, b.row, r, g, bl)
        }

        // Paddle — rendered at sub-pixel precision
        let ppx = Int(round((paddleX - paddleW / 2) * Double(s)))
        let ppy = paddleRow * s
        let ppw = Int(paddleW) * s
        for dy in 0..<s { for dx in 0..<ppw {
            setPixel(ppx + dx, ppy + dy, fgR, fgG, fgB)
        }}

        // Ball — rendered at sub-pixel precision
        let bpx = Int(round(ballX * Double(s)))
        let bpy = Int(round(ballY * Double(s)))
        for dy in 0..<s { for dx in 0..<s {
            setPixel(bpx + dx, bpy + dy, fgR, fgG, fgB)
        }}

        // Lives (tiny hearts)
        for i in 0..<lives {
            let bc = width - 4 - i * 4
            setCell(bc, 0, dimR, dimG, dimB)
            setCell(bc + 2, 0, dimR, dimG, dimB)
            setCell(bc + 1, 1, dimR, dimG, dimB)
        }

        // Score
        drawScore(score, startCol: 1, row: 0, &px, fgR: dimR, fgG: dimG, fgB: dimB)

        // TAP overlay
        if waitingToStart || gameOver || won {
            drawText("TAP", centerRow: 10, &px, fgR: fgR, fgG: fgG, fgB: fgB)
        }

        return px
    }

    // MARK: - Pixel Fonts

    private func drawText(_ text: String, centerRow: Int, _ pixels: inout [UInt8],
                          fgR: UInt8, fgG: UInt8, fgB: UInt8) {
        let rw = renderWidth
        let s = scale
        let chars = Array(text)
        let cw = 3, ch = 4, sp = 1
        let startCol = (width - chars.count * cw - (chars.count - 1) * sp) / 2
        for (i, c) in chars.enumerated() {
            let bm = pixelFont(c)
            let cx = startCol + i * (cw + sp)
            for r in 0..<ch { for col in 0..<cw {
                if bm[r * cw + col] == 1 {
                    let gx = cx + col, gy = centerRow + r
                    guard gx >= 0, gx < width, gy >= 0, gy < height else { continue }
                    let sx = gx * s, sy = gy * s
                    for dy in 0..<s { for dx in 0..<s {
                        let o = ((sy + dy) * rw + sx + dx) * 4
                        pixels[o] = fgR; pixels[o+1] = fgG; pixels[o+2] = fgB
                    }}
                }
            }}
        }
    }

    private func drawScore(_ value: Int, startCol: Int, row: Int, _ pixels: inout [UInt8],
                           fgR: UInt8, fgG: UInt8, fgB: UInt8) {
        let rw = renderWidth
        let s = scale
        let cw = 3, ch = 5
        var col = startCol
        for c in String(value) {
            let bm = scoreFont(c)
            for r in 0..<ch { for cc in 0..<cw {
                if bm[r * cw + cc] == 1 {
                    let gx = col + cc, gy = row + r
                    guard gx >= 0, gx < width, gy >= 0, gy < height else { continue }
                    let sx = gx * s, sy = gy * s
                    for dy in 0..<s { for dx in 0..<s {
                        let o = ((sy + dy) * rw + sx + dx) * 4
                        pixels[o] = fgR; pixels[o+1] = fgG; pixels[o+2] = fgB
                    }}
                }
            }}
            col += cw + 1
        }
    }

    private func pixelFont(_ ch: Character) -> [Int] {
        switch ch {
        case "T": return [1,1,1, 0,1,0, 0,1,0, 0,1,0]
        case "A": return [0,1,0, 1,0,1, 1,1,1, 1,0,1]
        case "P": return [1,1,0, 1,0,1, 1,1,0, 1,0,0]
        default:  return [0,0,0, 0,0,0, 0,0,0, 0,0,0]
        }
    }

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
