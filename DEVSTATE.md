# Zrno Development State

**Last updated:** 2026-03-16
**Status:** Builds successfully, 4 benign warnings

---

## What Zrno Is

A film photography light meter iOS app. Uses the iPhone camera to measure light (EV), then recommends aperture/shutter speed combos for a user-configured film camera profile. Includes hidden pixel games (Zrnoid and Zrnorun) accessible via Fun Mode.

---

## Architecture

### Models (SwiftData)
- **CameraProfile** (`CameraProfile.swift`) — name, apertures, shutterSpeeds, filmISO, exposureCompensation, isSelected, shutterCalibration, lenses relationship, pinhole camera support (type, pinholeAperture, pinholeDiameterMM, pinholeFocalLengthMM, schwarzschildP, filmPreset)
- **Lens** (`Lens.swift`) — name, focalLength (mm), apertures, isSelected, cameraProfile relationship

### Services
- **LightMeterService** (`LightMeterService.swift`) — @Observable, AVCaptureSession, measures EV via KVO on exposure/ISO, generates 36x24 monochrome preview image + 256-bin histogram with temporal smoothing, multi-camera support, priority modes (auto/aperturePriority/shutterPriority), exposure status detection (correct/underExposed/overExposed), meter reliability (normal/lowLight/overExposed), simulator fallback

### Core Logic
- **ExposureCalculator** (`ExposureCalculator.swift`) — pure static functions: calculateEV100, bestExposure, allCombinations, nearestValue, shutterSpeed/aperture solving, Schwarzschild reciprocity correction, formatters (shutter speed, aperture, EV, long exposure), film reciprocity presets

### Theme System
- **AppTheme** (`AppTheme.swift`) — @Observable class, persisted to UserDefaults
  - `scheme: ThemeScheme` (noir/cream/blueSteel/darkroomRed)
  - `fontDesign: ThemeFontDesign` (rounded/standard/monospaced/serif)
  - `appearanceMode: AppearanceMode` (system/light/dark)
  - `effectiveIsDark: Bool` — drives all color lookups
  - Convenience: `backgroundColor`, `primaryColor`, `secondaryColor` (primary @ 0.4), `accentColor` (primary @ 0.7)
  - Passed via `@Environment(\.appTheme)`

### Games (Fun Mode)
- **ArkanoidGame** (`ArkanoidGame.swift`) — Breakout-style pixel game, 36x24 grid rendered at 4x scale (144x96), 30fps timer, accelerometer paddle control, 5 rows of bricks, 3 lives, soft ball trail, high score persistence
- **RunnerGame** (`RunnerGame.swift`) — Endless runner, 36x24 grid, 60fps timer, accelerometer not used (tap to jump), obstacle generation, speed increases every 300 ticks, high score persistence
- **PreviewMode** (`PreviewMode.swift`) — Enum: .histogram, .camera, .game, .runner. `next(funMode:)` / `previous(funMode:)` skip games when fun mode is off

### Views
| File | Purpose |
|------|---------|
| `ZrnoApp.swift` | Entry point, ModelContainer setup |
| `ContentView.swift` | Main screen: GeometryReader (keyboard protection), top bar (profile button, ZRNO, settings), MeterView, sheets for profiles/ISO/settings, default profile creation |
| `MeterView.swift` | Exposure display: aperture (lockable via PriorityValuePicker), shutter speed (lockable), animated EV/status label, compensation dial, scene preview, bottom bar (profile name, lens swiper, ISO button, camera selector) |
| `CompensationDialView.swift` | Horizontal scroll dial ±3EV in 1/3 stops, tickSpacing=28, isDragging flag |
| `ScenePreviewView.swift` | Swipeable: histogram / camera preview / Zrnoid / Zrnorun. Pixel transition animation between modes. UIKit GestureOverlay for instant tap response. Fun mode gating. |
| `HistogramView.swift` | Canvas-drawn luminance histogram |
| `PriorityValuePicker.swift` | Horizontal scroll of value chips for locked aperture/shutter selection |
| `CameraSelectorView.swift` | iPhone camera lens selector (ultra-wide/wide/tele) |
| `ExposureTableView.swift` | All valid aperture/shutter combos list |
| `SettingsView.swift` | Appearance, Color Scheme, Font, About (Guide, Fun Mode toggle, high scores) |
| `DocumentationView.swift` | User guide with hidden Games section (visible when fun mode on) |
| `ProfileListView.swift` | Camera profile list, select/edit/delete/add |
| `ProfileEditorView.swift` | Edit camera: name, ISO, lenses section, shutter speed grid, calibration, pinhole settings |
| `LensEditorView.swift` | Edit lens: name, focal length, aperture grid |
| `ISOPickerView.swift` | ISO selection sheet |

---

## Critical Rules

### NEVER remove the GeometryReader in ContentView.swift
The GeometryReader wrapping the body content prevents the keyboard from pushing the top bar up. It's documented with a comment on line 21. **Do not remove it under any circumstances.**

### Theme Rules
All colors MUST be theme-relative. Never use hardcoded `.black`, `.white`, etc.

- **Background:** `theme.backgroundColor`
- **Text/icons:** `theme.primaryColor` (high contrast) or `theme.secondaryColor` (muted)
- **Accent/highlights:** `theme.accentColor`
- **Button backgrounds:** `theme.primaryColor.opacity(0.06)` for default, `theme.primaryColor.opacity(0.12)` for selected
- **Sheet modifiers (ALL required together):**
  - `.scrollContentBackground(.hidden)`
  - `.background(theme.backgroundColor)`
  - `.presentationCornerRadius(16)`
  - `.presentationBackground(theme.backgroundColor)`
  - `.toolbarBackground(theme.backgroundColor, for: .navigationBar)`
  - `.listRowBackground(theme.primaryColor.opacity(0.06))`
- **All interactive elements:** `.buttonStyle(.plain)` to remove shadows
- **List style:** `.listStyle(.plain)` — never use Form
- **Fonts in sheets/menus:** `.monospaced` design

---

## Approved Components (DO NOT CHANGE)

### Top Bar — APPROVED
Lives in `ContentView.swift`. Do not modify.
- Left: camera.aperture icon button
- Center: "ZRNO" text, monospaced 15pt semibold, tracking 4
- Right: gearshape icon button
- All respond correctly to light/dark mode and all color schemes

### Compensation Dial — APPROVED
Lives in `CompensationDialView.swift`. Do not modify without direct request.
- ±3 EV range in 1/3 stops, tickSpacing=28
- Indicator line: 2px wide, 18pt tall, theme.accentColor
- Value label: 14pt monospaced, secondaryColor at ±0, accentColor otherwise

---

## Test Coverage

### Unit Tests (`ZrnoTests/`)
| File | Coverage |
|------|----------|
| `ExposureCalculatorTests.swift` | EV calculation, solving, best exposure, all combinations, formatting, nearest value, standard values, compensation, Schwarzschild, pinhole, film presets, calibration |
| `LightMeterServiceTests.swift` | Priority modes, recommendation (auto/aperture/shutter/pinhole), debounce, focal length selection, exposure status, reliability, quantized EV, combination population |
| `ModelTests.swift` | CameraProfile, CameraType, Lens, PreviewMode (cycling, available, round-trips, encoding), MeterMode, MeterReliability, ExposureStatus, CameraLens, extended profile tests |
| `GameTests.swift` | RunnerGame (initial state, start/stop, tap, jump, render, high score key, double start), ArkanoidGame (initial state, start/stop, bricks, tap, lives, render, restart, paddle/ball position) |
| `AppThemeTests.swift` | AppearanceMode, ThemeScheme, ThemeFontDesign, AppTheme (defaults, opacity, design, appearance, save/persist) |

### UI Tests (`ZrnoUITests/`)
- Meter screen elements (aperture, shutter, ISO, profile, settings, EV label, ZRNO branding)
- Scene preview existence
- Priority mode toggle (aperture, shutter)
- ISO picker (open/close, standard values)
- Profile list (open/close, default profile)
- Settings (open/close, appearance section, color scheme)
- Compensation dial (existence, label, swipe changes value)
- Keyboard toolbar test (editor keyboard doesn't push topbar)
- Layout stability (rotation test, portrait integrity, landscape integrity)
- Launch performance

---

## Known Issues

### Rotation Layout Bug (UNSOLVED — iOS system bug)
On physical iPhone SE 3rd gen, rotating portrait → landscape → portrait causes the layout to shift upward slightly. Going to app switcher and back fixes it. **Not reproducible in simulator.** Same issue observed in Apple's Notes app — this is an iOS/SwiftUI system-level bug with GeometryReader and rotation, not specific to Zrno. Multiple fix attempts failed:
1. Removing `.frame(maxHeight: .infinity)` from ScenePreviewView — didn't help
2. Moving GestureOverlay to overlay — didn't help
3. `.id(vSizeClass)` / `.id(orientation)` to force re-layout — didn't help
4. Explicit `.frame(width:height:)` from GeometryReader size — didn't help

### Build Warnings (4, all benign)
1. MeterView.swift — "Call to main actor-isolated static method 'formatAperture' in a synchronous nonisolated context"
2. MeterView.swift — "Call to main actor-isolated static method 'formatShutterSpeed' in a synchronous nonisolated context"
3. LightMeterService.swift — "'nonisolated(unsafe)' has no effect on property 'frameSkipCounter'"
4. LightMeterService.swift — "Call to main actor-isolated instance method 'buildHistogram' in a synchronous nonisolated context"

---

## Default Profiles

### Basic (built-in, non-editable)
- Apertures: 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0
- Shutter speeds: standard range
- Default lens: "–", 50mm

### Mamiya 7 (migrated default)
- Shutter speeds: 1/500, 1/250, 1/125, 1/60, 1/30, 1/15, 1/8, 1/4, 1/2, 1″, 2″, 4″
- Default lens: "N 80mm f/4 L", 80mm, apertures [4.0, 5.6, 8.0, 11.0, 16.0, 22.0]

---

## Rules
1. NEVER remove the GeometryReader from ContentView
2. NEVER remove existing functionality
3. ALWAYS write tests for new features
4. Test ALL color scheme + appearance mode combinations
5. Check that every color reference uses theme.* not hardcoded values
6. Before changing any approved component, re-read this section first
7. RunnerGame stays at 60fps (physics tuned for it)
8. ArkanoidGame stays at 30fps with 4x scale

---

## Roadmap (NOT implementing yet)
- Film rolls: `FilmRoll` model with `Frame` children storing per-frame exposure
- Freeze settings: "hold" button locking displayed values
- Front camera metering
- Spot metering: tap preview to set metering point
- Preferred aperture setting: let user choose preferred aperture in Settings
