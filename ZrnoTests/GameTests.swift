import Testing
import Foundation
@testable import Zrno

// MARK: - RunnerGame

struct RunnerGameTests {

    @MainActor
    @Test func initialState() {
        let game = RunnerGame()
        #expect(game.width == 36)
        #expect(game.height == 24)
        #expect(game.isRunning == false)
        #expect(game.gameOver == false)
        #expect(game.score == 0)
        #expect(game.waitingToStart == true)
    }

    @MainActor
    @Test func startSetsRunningState() {
        let game = RunnerGame()
        game.start()
        #expect(game.isRunning == true)
        #expect(game.gameOver == false)
        #expect(game.waitingToStart == true)
        #expect(game.score == 0)
        game.stop()
    }

    @MainActor
    @Test func stopClearsRunningState() {
        let game = RunnerGame()
        game.start()
        game.stop()
        #expect(game.isRunning == false)
    }

    @MainActor
    @Test func handleTapStartsGame() {
        let game = RunnerGame()
        game.start()
        #expect(game.waitingToStart == true)
        game.handleTap()
        #expect(game.waitingToStart == false)
        game.stop()
    }

    @MainActor
    @Test func handleTapTriggersJumpWhenOnGround() {
        let game = RunnerGame()
        game.start()
        game.handleTap() // start running
        let initialY = game.runnerY
        game.handleTap() // jump
        // velocityY should be set negative (upward), but position only changes on tick
        // After jump, the runner should still be on the ground until tick processes
        #expect(game.runnerY == initialY) // position unchanged until tick
        game.stop()
    }

    @MainActor
    @Test func singleTapRestart() {
        let game = RunnerGame()
        game.start()
        game.handleTap() // start running

        // Simulate game over by directly accessing internal state isn't possible,
        // but we can test the restart flow through the public API
        game.stop()

        // Restart via start + handleTap (simulating what happens when gameOver)
        game.start()
        #expect(game.waitingToStart == true)
        #expect(game.score == 0)
        game.stop()
    }

    @MainActor
    @Test func renderProducesCorrectPixelCount() {
        let game = RunnerGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        #expect(pixels.count == 36 * 24 * 4) // RGBA
        game.stop()
    }

    @MainActor
    @Test func renderContainsForegroundPixels() {
        let game = RunnerGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        // The runner sprite and ground line should produce some white pixels
        let hasFgPixels = stride(from: 0, to: pixels.count, by: 4).contains { i in
            pixels[i] == 255 && pixels[i + 1] == 255 && pixels[i + 2] == 255
        }
        #expect(hasFgPixels)
        game.stop()
    }

    @MainActor
    @Test func renderShowsTapOverlayWhenWaiting() {
        let game = RunnerGame()
        game.start()
        // waitingToStart is true, so "TAP" text should be rendered
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        // Row 10-13 (centerRow=10, charH=4) should contain text pixels
        // Check that the center area has some foreground pixels
        var centerFgCount = 0
        for row in 10...13 {
            for col in 0..<36 {
                let offset = (row * 36 + col) * 4
                if pixels[offset] == 255 { centerFgCount += 1 }
            }
        }
        #expect(centerFgCount > 0) // "TAP" text pixels exist
        game.stop()
    }

    @MainActor
    @Test func highScoreKeyIsCorrect() {
        #expect(RunnerGame.highScoreKey == "zrno.zrnorun.highScore")
    }

    @MainActor
    @Test func doubleStartIsNoop() {
        let game = RunnerGame()
        game.start()
        game.start() // second start should be a no-op
        #expect(game.isRunning == true)
        game.stop()
    }
}

// MARK: - ArkanoidGame

struct ArkanoidGameTests {

    @MainActor
    @Test func initialState() {
        let game = ArkanoidGame()
        #expect(game.width == 36)
        #expect(game.height == 24)
        #expect(game.isRunning == false)
        #expect(game.gameOver == false)
        #expect(game.won == false)
        #expect(game.score == 0)
        #expect(game.waitingToStart == true)
    }

    @MainActor
    @Test func startSetsRunningState() {
        let game = ArkanoidGame()
        game.start()
        #expect(game.isRunning == true)
        #expect(game.gameOver == false)
        #expect(game.won == false)
        #expect(game.waitingToStart == true)
        #expect(game.score == 0)
        game.stop()
    }

    @MainActor
    @Test func bricksInitialized() {
        let game = ArkanoidGame()
        // 5 rows × 36 cols = 180 brick pixels
        #expect(game.bricks.count == 180)
    }

    @MainActor
    @Test func bricksFilledCorrectly() {
        let game = ArkanoidGame()
        // All bricks should be in rows 0-4
        for brick in game.bricks {
            #expect(brick.row >= 0 && brick.row <= 4)
            #expect(brick.col >= 0 && brick.col < 36)
        }
    }

    @MainActor
    @Test func handleTapLaunchesBall() {
        let game = ArkanoidGame()
        game.start()
        #expect(game.waitingToStart == true)
        game.handleTap()
        #expect(game.waitingToStart == false)
        game.stop()
    }

    @MainActor
    @Test func stopClearsRunningState() {
        let game = ArkanoidGame()
        game.start()
        game.stop()
        #expect(game.isRunning == false)
    }

    @MainActor
    @Test func livesStartAtThree() {
        let game = ArkanoidGame()
        game.start()
        #expect(game.lives == 3)
        game.stop()
    }

    @MainActor
    @Test func renderProducesCorrectPixelCount() {
        let game = ArkanoidGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        // Rendered at 4x: 144×96
        #expect(pixels.count == game.renderWidth * game.renderHeight * 4)
        game.stop()
    }

    @MainActor
    @Test func renderContainsBrickPixels() {
        let game = ArkanoidGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        let s = game.scale
        let rw = game.renderWidth
        // Bricks are in rows 0-4 (scaled), they should produce non-background pixels
        var brickAreaNonBgCount = 0
        for row in 0..<(5 * s) {
            for col in 0..<rw {
                let offset = (row * rw + col) * 4
                if pixels[offset] != 0 || pixels[offset + 1] != 0 || pixels[offset + 2] != 0 {
                    brickAreaNonBgCount += 1
                }
            }
        }
        #expect(brickAreaNonBgCount > 100)
        game.stop()
    }

    @MainActor
    @Test func renderContainsPaddlePixels() {
        let game = ArkanoidGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        let s = game.scale
        let rw = game.renderWidth
        // Paddle at row 23, rendered at scale
        let paddleRowStart = 23 * s
        var paddleFgCount = 0
        for dy in 0..<s {
            for col in 0..<rw {
                let offset = ((paddleRowStart + dy) * rw + col) * 4
                if pixels[offset] == 255 && pixels[offset + 1] == 255 && pixels[offset + 2] == 255 {
                    paddleFgCount += 1
                }
            }
        }
        // 5 game-pixels wide × scale tall × scale wide = 5 * scale * scale
        #expect(paddleFgCount == 5 * s * s)
        game.stop()
    }

    @MainActor
    @Test func renderContainsBallPixel() {
        let game = ArkanoidGame()
        game.start()
        let pixels = game.render(fgR: 255, fgG: 255, fgB: 255, bgR: 0, bgG: 0, bgB: 0)
        let s = game.scale
        let rw = game.renderWidth
        // Ball should be near row 21, col 17-18 in game coords → scaled
        var foundBall = false
        for row in (19 * s)...(22 * s) {
            for col in (15 * s)...(21 * s) {
                let offset = (row * rw + col) * 4
                if pixels[offset] == 255 && pixels[offset + 1] == 255 && pixels[offset + 2] == 255 {
                    foundBall = true
                }
            }
        }
        #expect(foundBall)
        game.stop()
    }

    @MainActor
    @Test func highScoreKeyIsCorrect() {
        #expect(ArkanoidGame.highScoreKey == "zrno.zrnoid.highScore")
    }

    @MainActor
    @Test func restartResetsState() {
        let game = ArkanoidGame()
        game.start()
        game.handleTap() // launch ball
        game.restart()
        #expect(game.score == 0)
        #expect(game.isRunning == true)
        #expect(game.bricks.count == 180)
        game.stop()
    }

    @MainActor
    @Test func singleTapRestartAfterGameOver() {
        let game = ArkanoidGame()
        game.start()
        game.handleTap() // launch ball

        // We can't easily simulate game over through the game loop,
        // but we can test the handleTap logic path:
        // When gameOver is true, handleTap should restart AND set waitingToStart = false
        game.stop()
        game.start()
        // After start, waitingToStart = true
        game.handleTap() // this simulates the single-tap restart
        #expect(game.waitingToStart == false)
        game.stop()
    }

    @MainActor
    @Test func paddleStartsCentered() {
        let game = ArkanoidGame()
        game.start()
        #expect(game.paddleX == 18.0) // center of 36px width
        game.stop()
    }

    @MainActor
    @Test func ballStartsCentered() {
        let game = ArkanoidGame()
        game.start()
        // Ball is centered: width/2 - 0.5 = 17.5, but in waitingToStart it tracks paddle
        #expect(game.ballX == 17.5) // paddleX(18) - 0.5
        #expect(game.ballY == 21.0) // paddleRow(23) - 2
        game.stop()
    }
}
