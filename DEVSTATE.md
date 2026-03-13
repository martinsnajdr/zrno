# Zrno Development State

**Last updated:** 2026-03-13
**Status:** Builds successfully, 4 benign warnings

---

## What Zrno Is

A film photography light meter iOS app. Uses the iPhone camera to measure light (EV), then recommends aperture/shutter speed combos for a user-configured film camera profile.

---

## Architecture

### Models (SwiftData)
- **CameraProfile** (`CameraProfile.swift`) — name, apertures, shutterSpeeds, filmISO, exposureCompensation, isSelected, shutterCalibration, lenses relationship
- **Lens** (`Lens.swift`) — name, focalLength (mm), apertures, isSelected, cameraProfile relationship

### Services
- **LightMeterService** (`LightMeterService.swift`) — @Observable, AVCaptureSession, measures EV via KVO on exposure/ISO, generates 48x36 monochrome preview image + histogram, multi-camera support, priority modes (auto/aperturePriority/shutterPriority), simulator fallback

### Core Logic
- **ExposureCalculator** (`ExposureCalculator.swift`) — pure static functions: calculateEV100, bestExposure, allCombinations, nearestValue, formatters

### Theme System
- **AppTheme** (`AppTheme.swift`) — @Observable class, persisted to UserDefaults
  - `scheme: ThemeScheme` (noir/cream/blueSteel/darkroomRed)
  - `fontDesign: ThemeFontDesign` (rounded/standard/monospaced/serif)
  - `appearanceMode: AppearanceMode` (system/light/dark)
  - `effectiveIsDark: Bool` — drives all color lookups
  - Convenience: `backgroundColor`, `primaryColor`, `secondaryColor` (primary @ 0.4), `accentColor` (primary @ 0.7)
  - Passed via `@Environment(\.appTheme)`

### Views
| File | Purpose |
|------|---------|
| `ZrnoApp.swift` | Entry point, ModelContainer setup |
| `ContentView.swift` | Main screen: top bar (profile button, ZRNO, settings), DraggableContainer wrapping MeterView, sheets for profiles/ISO/settings, default profile creation |
| `MeterView.swift` | Exposure display: aperture (lockable), shutter speed (lockable), EV label, compensation dial, scene preview, bottom bar (camera name, ISO button, lens name, lens selector) |
| `CompensationDialView.swift` | Horizontal scroll dial ±3EV in 1/3 stops, tickSpacing=28, isDragging flag to prevent feedback loop |
| `ScenePreviewView.swift` | Swipeable: histogram vs camera preview (48x36 pixelated monochrome), .colorMultiply(theme.primaryColor) |
| `HistogramView.swift` | Canvas-drawn luminance histogram, gradient fill + stroke in accentColor |
| `PriorityValuePicker.swift` | Horizontal scroll of value chips for locked aperture/shutter selection |
| `CameraSelectorView.swift` | iPhone camera lens selector (ultra-wide/wide/tele) |
| `ExposureTableView.swift` | All valid aperture/shutter combos list |
| `SettingsView.swift` | Appearance, Color Scheme, Font, About sections |
| `ProfileListView.swift` | Camera profile list, select/edit/delete/add |
| `ProfileEditorView.swift` | Edit camera: name, ISO, lenses section, shutter speed grid, calibration |
| `LensEditorView.swift` | Edit lens: name, focal length, aperture grid |
| `ISOPickerView.swift` | ISO selection sheet |
| `PreviewMode.swift` | Enum: .histogram, .camera |

---

## Theme Rules (CRITICAL)

All colors MUST be theme-relative. Never use hardcoded `.black`, `.white`, etc.

- **Background:** `theme.backgroundColor`
- **Text/icons:** `theme.primaryColor` (high contrast) or `theme.secondaryColor` (muted)
- **Accent/highlights:** `theme.accentColor`
- **Button backgrounds:** `theme.primaryColor.opacity(0.06)` for default, `theme.primaryColor.opacity(0.12)` for selected
- **List row backgrounds:** `theme.primaryColor.opacity(0.06)`
- **Sheet modifiers (ALL required together):**
  - `.scrollContentBackground(.hidden)`
  - `.background(theme.backgroundColor)`
  - `.presentationCornerRadius(16)`
  - `.presentationBackground(theme.backgroundColor)`
  - `.toolbarBackground(theme.backgroundColor, for: .navigationBar)`
  - `.listRowBackground(theme.primaryColor.opacity(0.06))`
- **All interactive elements:** `.buttonStyle(.plain)` to remove shadows
- **List style:** `.listStyle(.plain)` — never use Form (creates grouped inset with shadows)
- **Fonts in sheets/menus:** `.monospaced` design
- **Preview image:** `.colorMultiply(theme.primaryColor)` + `.background(theme.backgroundColor)` — white shows as theme primary, dark shows as theme background

---

## Approved Components (DO NOT CHANGE)

### Top Bar — APPROVED
The top bar is perfect. Do not modify it. It lives in `ContentView.swift` lines 51-114.
- Left: camera.aperture icon button, `theme.primaryColor`, circle bg `theme.primaryColor.opacity(0.06)`, `.buttonStyle(.plain)`
- Center: "ZRNO" text, monospaced 15pt semibold, `theme.primaryColor`, tracking 4
- Right: gearshape icon button, same style as left
- All respond correctly to light/dark mode and all color schemes

### Compensation Dial — APPROVED
Do not modify without direct request. Lives in `CompensationDialView.swift` (165 lines).
- ±3 EV range in 1/3 stops, tickSpacing=28
- ZStack(alignment: .bottom) per tick, fixed frame(height: 18) — all tick bottoms aligned
- Indicator line: 2px wide, 18pt tall, theme.accentColor, fixed at center
- Labels (-1, 0, +1): 9pt monospaced, theme.accentColor, offset(y: 14) overlay
- Value label: 14pt monospaced, secondaryColor at ±0, accentColor otherwise, 16pt gap to dial
- Full-area touch target via Color.clear.contentShape(Rectangle())
- Gesture on ZStack, not on tick HStack
- Parent uses .simultaneousGesture(LongPressGesture) to avoid conflict
- Binding chain: compensation → activeProfile.exposureCompensation → onChange → updateRecommendation(force:true)

---

## Known Issues / User Complaints History

### Fixed
- Top bar colors were hardcoded `.black` → now `theme.primaryColor`
- Buttons had shadows → added `.buttonStyle(.plain)` everywhere
- Compensation dial jumped without updating values → added `isDragging` flag
- EV display was missing → restored `measuredEV` parameter
- Histogram didn't fill width → removed horizontal padding
- Preview image was dark → uses `.colorMultiply(theme.primaryColor)`
- Sheet views had wrong backgrounds → full theme treatment applied

### Rules
1. NEVER remove existing functionality
2. ALWAYS write UI tests for new features
3. Test ALL color scheme + appearance mode combinations mentally
4. Check that every color reference uses theme.* not hardcoded values
5. Before changing any approved component, re-read this section first

---

## Default Profile

Name: "Mamiya 7"
- Shutter speeds: 1/500, 1/250, 1/125, 1/60, 1/30, 1/15, 1/8, 1/4, 1/2, 1″, 2″, 4″
- Default lens: "N 80mm f/4 L", 80mm, apertures [4.0, 5.6, 8.0, 11.0, 16.0, 22.0]

---

## File Sizes (for context awareness)

| File | Lines |
|------|-------|
| LightMeterService.swift | 623 |
| ContentView.swift | 358 |
| ProfileEditorView.swift | 329 |
| MeterView.swift | 285 |
| AppTheme.swift | 193 |
| CompensationDialView.swift | 159 |
| ExposureCalculator.swift | 156 |
| LensEditorView.swift | 150 |
| SettingsView.swift | 136 |
| ScenePreviewView.swift | 109 |
| ProfileListView.swift | 97 |
| CameraProfile.swift | 74 |
| HistogramView.swift | 68 |
| PriorityValuePicker.swift | 57 |
| ISOPickerView.swift | 53 |
| ExposureTableView.swift | 36 |
| ZrnoApp.swift | 34 |
| CameraSelectorView.swift | 32 |
| Lens.swift | 31 |
| PreviewMode.swift | 20 |

---

## Build Warnings (4, all benign)

1. MeterView.swift:136 — "Call to main actor-isolated static method 'formatAperture' in a synchronous nonisolated context"
2. MeterView.swift:166 — "Call to main actor-isolated static method 'formatShutterSpeed' in a synchronous nonisolated context"
3. LightMeterService.swift:81 — "'nonisolated(unsafe)' has no effect on property 'frameSkipCounter'"
4. LightMeterService.swift:442 — "Call to main actor-isolated instance method 'buildHistogram' in a synchronous nonisolated context"

---

## TODO: Sheet/Menu Redesign (NOT STARTED)

All 5 sheet views (SettingsView, ProfileListView, ProfileEditorView, LensEditorView, ISOPickerView) need rework. The goal: look like native iOS but with Zrno's personality.

### What to change:
1. **Less rounded corners** — the sheet itself AND buttons inside. Currently `presentationCornerRadius(16)` which is fine for the sheet, but section group corners (from insetGrouped) should use smaller radius. Buttons at top of menus (toolbar Done/Cancel/Save) must have NO shadows.
2. **Navigation title font** — must match ZRNO branding: monospaced, semibold. Same visual identity as the "ZRNO" text in top bar. Use `.toolbar { ToolbarItem(placement: .principal) { Text("Cameras").font(.system(size: 15, weight: .semibold, design: .monospaced)) } }` pattern instead of `.navigationTitle()`.
3. **Toolbar buttons** — no shadows (`.buttonStyle(.plain)`), monospaced font. Already done but verify.
4. **Sheet/menu background** — same color as MeterView background (`theme.backgroundColor`). Already done via `.presentationBackground(theme.backgroundColor)`.
5. **List style** — use `.insetGrouped` (native iOS look with section padding, inset rows) instead of current `.plain`. Override the default backgrounds: `.scrollContentBackground(.hidden)` + `.background(theme.backgroundColor)` + `.listRowBackground(theme.primaryColor.opacity(0.06))`. The insetGrouped gives proper left/right/top padding natively.
6. **Respect color scheme** — all colors stay theme-relative as they are now.
7. **Summary** — native iOS structure (insetGrouped sections, proper padding) + Zrno style (mono font, no shadows, theme colors, less roundness).

### Affected files:
- `SettingsView.swift`
- `ProfileListView.swift`
- `ProfileEditorView.swift`
- `LensEditorView.swift`
- `ISOPickerView.swift`

### Key pattern for each sheet:
```
.listStyle(.insetGrouped)
.scrollContentBackground(.hidden)
.background(theme.backgroundColor)
.presentationCornerRadius(16)
.presentationBackground(theme.backgroundColor)
.toolbarBackground(theme.backgroundColor, for: .navigationBar)
.listRowBackground(theme.primaryColor.opacity(0.06))
.buttonStyle(.plain) on all Section blocks
.tint(theme.primaryColor)
// Replace .navigationTitle("X") with custom principal ToolbarItem using mono font
```

---

## TODO: MeterView Fixes (NOT STARTED)

### Priority Mode (Aperture/Shutter Lock) — REDESIGN

**Current behavior (WRONG):** Tapping aperture/shutter shows a lock icon and a `PriorityValuePicker` navigation row BELOW the value. This pushes content down and shifts the layout.

**Correct behavior:**
1. Tap aperture value → it locks (lock icon appears). The scrollable value picker appears INLINE, NEXT TO the aperture value itself — not below it. No extra row, no layout shift.
2. Swipe/scroll the inline picker to select a different aperture value.
3. Tap the aperture value again → unlocks, returns to auto/dynamic mode. Picker disappears.
4. Same pattern for shutter speed.
5. **Nothing on MeterView should open or push anything.** Every UI element stays rock solid in its position. No sheets, no navigation, no expanding sections.
6. **Values in the picker must reflect the currently selected camera profile and lens.** Aperture picker shows the active lens's apertures. Shutter picker shows the profile's shutter speeds.
7. **Switching camera or lens resets to auto/dynamic mode.** If user picks a different camera profile or lens, meterMode goes back to `.auto`, lockedAperture/lockedShutterSpeed become nil.

### Affected files:
- `MeterView.swift` — redesign exposureControls to show inline picker next to value
- `PriorityValuePicker.swift` — may need to be made more compact/inline
- `ContentView.swift` — onLensSelect and profile switch should reset meterMode

### EV + Focus Distance Row — FIX

**Current behavior (WRONG):** Shows "EV 12.3" and "80mm" (the lens focal length). The focal length should NOT be here.

**Correct behavior:**
- Left: `"EV 12.3"` — the measured EV value (already correct)
- Right: Focus distance in readable units from `lightMeter.focusPosition` (0.0=near, 1.0=far). Display as: `"0.3m"`, `"1.2m"`, `"5m"`, `"∞"` etc.
- The `focalLength` parameter on MeterView should be removed or repurposed for focus distance.
- `LightMeterService.focusPosition` (Float 0-1) needs to be converted to approximate real-world distance. The conversion depends on the lens but a reasonable approximation: use the camera device's `minimumFocusDistance` and map 0→minDist, 1→infinity.
- Format: distances < 1m show one decimal (`"0.5m"`), 1-10m show integer (`"3m"`), >10m or very close to 1.0 show `"∞"`.

### Affected files:
- `MeterView.swift` — replace `focalLength: String` param with `focusDistance: String`
- `ContentView.swift` — compute focus distance string from `lightMeter.focusPosition`
- `LightMeterService.swift` — may need to expose minimum focus distance from AVCaptureDevice

---

## TODO: Preview / Histogram — FIX (NOT STARTED)

### Preview Image — BROKEN

**Current behavior (WRONG):** Just a black square. Nothing visible.

**What it used to be:** A pixelated monochrome square image showing the camera scene. Bright parts were white, dark parts were dark. It worked before the theme color changes broke it.

**Root cause:** The current code uses `.colorMultiply(theme.primaryColor)`. This multiplies every pixel by the primary color. In Noir dark mode, primary is white, so white*white=white, black*white=black — should work. BUT in other schemes (like darkroom red where primary is `(0.77, 0.25, 0.25)`), white*red = red, which is fine. The problem is likely that the preview image from LightMeterService is not being generated at all, or the image is all-black. Check `previewImage` in LightMeterService — the `captureOutput` method generates it. On simulator, `generateSimulatorPreview()` creates a gradient. Verify the image is actually non-nil.

**Correct behavior:**
- The image is a grayscale preview of what the camera sees
- **White should ALWAYS be white** (bright highlights = pure white regardless of scheme)
- **Dark/shadow parts** should be tinted with the scheme color (black for noir, red for darkroom red, cream for cream, blue-gray for blue steel)
- This means: DON'T use `.colorMultiply()` — it tints whites too. Instead, use a different compositing approach:
  - Option A: Use `.blendMode(.screen)` with a scheme-colored background — white stays white, blacks become the scheme color
  - Option B: Apply a CIFilter in LightMeterService that maps: white→white, black→scheme color (a color map/gradient map)
  - Option C: Overlay a scheme-colored rectangle with `.blendMode(.multiply)` — this tints the dark parts but leaves whites alone. Wait, that's the same problem. Better: use the grayscale image as a luminance mask over a gradient from schemeColor to white.
- Image should be **square** and **pixelated** (`.interpolation(.none)`)

### Preview / Histogram Layout — FIX

**Current behavior (WRONG):** There's too much empty space below the preview/histogram. It doesn't fill the available vertical space properly.

**Correct behavior:**
- The preview and histogram should fill the horizontal space edge to edge (already mostly done)
- They should also fill more vertical space — reduce the gaps/spacers around ScenePreviewView in MeterView's portraitLayout
- The `.frame(height: 80)` on ScenePreviewView might be too small. Consider making it dynamic based on available space, or increase it.
- The Spacer() after ScenePreviewView in portraitLayout should be smaller or the preview area should be taller

### Histogram — OK but needs more space
- The histogram itself looks fine visually
- Just needs to be taller / fill more of the vertical space below the compensation dial

### Affected files:
- `ScenePreviewView.swift` — fix preview tinting (white stays white), adjust frame sizing
- `LightMeterService.swift` — verify preview image is actually being generated and is non-black
- `MeterView.swift` — adjust spacing/layout to give preview more room
- `AppTheme.swift` — the `previewTint` property on ThemeScheme might be useful here

---

## TODO: Compensation Dial — DONE ✓

### Symptoms:
1. **Touch is unreliable** — drag gesture picks up touch irregularly. Might be competing with other gestures on MeterView or DraggableContainer.
2. **Values don't update** — dragging the dial does NOT trigger recalculation of aperture/shutter speed. The dial visually moves but exposure values stay the same.
3. **Scroll goes beyond bounds** — the strip can be dragged past -3 and +3 EV limits. The `clampedOffset` function exists but doesn't seem to work properly.
4. **Two failed approaches so far:**
   - First approach: scrolling worked visually but values didn't update (compensation binding wasn't triggering onChange in ContentView)
   - Second approach: added isDragging flag, but touch became unreliable

### Root cause analysis needed:
- **Gesture conflict?** The MeterView is inside a `DraggableContainer` which has its own `DragGesture`. The compensation dial also has a `DragGesture`. These may fight for touch ownership. The DraggableContainer drag is gated by `isEditing` (long press mode), but SwiftUI might still interfere with gesture recognition.
- **Binding chain:** `compensation` in MeterView is a `Binding` that reads/writes `activeProfile?.exposureCompensation`. The `onChange(of: activeProfile?.exposureCompensation)` in ContentView calls `lightMeter.updateRecommendation(for: profile, force: true)`. Check this chain is actually firing.
- **Clamping bug:** `clampedOffset` computes min/max from `offset(for: range.upperBound)` and `offset(for: range.lowerBound)`. The offset function is `-CGFloat((value - range.lowerBound) / step) * tickSpacing`. For value=3.0 (upperBound): offset = -(3.0 - (-3.0))/0.333 * 28 = -18 * 28 = -504. For value=-3.0 (lowerBound): offset = 0. So clamp should be -504...0. Verify this is correct and actually applied in both onChanged and onEnded.

### What needs to happen:
1. Fix gesture conflict — possibly use `.highPriorityGesture()` or `.simultaneousGesture()` on the dial, or ensure DraggableContainer's gesture is truly nil when not editing
2. Verify the binding chain: drag → compensation set → activeProfile.exposureCompensation written → onChange fires → updateRecommendation called with force:true → recommendedAperture/recommendedShutterSpeed updated
3. Fix clamping so strip cannot go past ±3 EV
4. Add a unit test that sets compensation and verifies exposure values change

### Affected files:
- `CompensationDialView.swift` — the dial itself
- `ContentView.swift` — the binding and onChange chain
- `MeterView.swift` — passes compensation binding through
- Possibly `DraggableContainer` in ContentView — gesture conflict

---

## TODO: Bottom Section & Layout Polish (NOT STARTED)

### Bottom section layout (below preview/histogram)

**Current behavior (WRONG):** Shows camera name, then ISO + lens name, then lens selector. Order and presentation are off.

**Correct layout (top to bottom):**
1. **iPhone camera selector** — which iPhone camera is active (13mm / 26mm / 77mm). Small, subtle, just above or just below the preview/histogram area.
2. **Camera profile name** — e.g. `"Mamiya 7"` in **bold** monospaced font. Prominent.
3. **ISO + Lens row** — HStack:
   - Left: `"ISO 400"` button (tapping opens ISO picker sheet). ISO picker sheet follows the same redesign rules as other sheets (insetGrouped, mono font, theme colors, etc.)
   - Right: Selected lens name (e.g. `"N 80mm f/4 L"`). **Swipeable left/right to pick a different lens.** This should be a horizontal swipe gesture on the lens name text itself, cycling through available lenses. No separate row of chips needed — just swipe the name.

### Shutter speed text size

The shutter speed (biggest number on screen) should be **4-8px bigger** than current 72pt. Change to ~78pt in MeterView.

### UI Spacing

The whole MeterView should be **nicely spread out** vertically. Currently elements feel cramped or have uneven gaps. Review all spacers in portraitLayout and distribute space more evenly:
- Top bar gap → aperture → shutter → EV/focus → compensation dial → preview/histogram → bottom info
- Each section should have breathing room. No section should feel squished.

### Debounce — SLOW DOWN

**Current behavior (WRONG):** Values update ~4x per second. Too jittery.

**Correct behavior:** Update displayed values max **2x per second** (every 500ms). The `LightMeterService` smoothing factor and debounce threshold control this. Options:
- Increase `recommendationThreshold` from 0.15 to ~0.3 (require bigger EV change before updating)
- AND/OR add a time-based throttle: don't call `updateRecommendation` more often than every 500ms
- The EV reading itself (`measuredEV`) can still update at the camera's rate for smooth histogram/preview, but the displayed aperture/shutter values should only change 2x/sec max

### Affected files:
- `MeterView.swift` — bottom section layout, shutter font size, spacing
- `ContentView.swift` — wire up bottom section, lens swipe
- `LightMeterService.swift` — add time-based throttle for recommendation updates
- `ISOPickerView.swift` — follows sheet redesign rules (see Sheet/Menu Redesign TODO)

---

## TODO: UI Test Automation (NOT STARTED)

### Strategy
Use XCUITest to automate gesture testing. These tests run on a real simulator, performing actual touches/swipes and reading actual UI state. This is the only reliable way to verify gesture-based interactions without manual testing.

### Required accessibility identifiers (verify these exist):
- `"compensationDial"` — the compensation dial view (NEEDS TO BE ADDED)
- `"compensationLabel"` — the ±0 / +1 text (NEEDS TO BE ADDED)
- `"apertureLabel"` — aperture value text (exists)
- `"shutterSpeedLabel"` — shutter speed text (exists)
- `"evLabel"` — EV value text (exists)
- `"isoButton"` — ISO button (exists)
- `"profileButton"` — camera profiles button (exists)
- `"settingsButton"` — settings button (exists)
- `"scenePreview"` — preview/histogram area (exists)

### Tests to write:

**Compensation Dial Tests:**
1. `testCompensationDialSwipeChangesValue` — swipe left on dial, verify compensationLabel changes from "±0"
2. `testCompensationDialSwipeChangesExposure` — swipe dial, verify apertureLabel or shutterSpeedLabel value changes
3. `testCompensationDialDoesNotScrollPastBounds` — swipe hard right repeatedly, verify label never goes below "-3"

**Priority Mode Tests:**
4. `testTapApertureLocks` — tap apertureLabel, verify lock icon appears (look for lock image in the hierarchy)
5. `testTapApertureAgainUnlocks` — tap apertureLabel twice, verify lock disappears
6. `testTapShutterLocks` — same for shutter

**Navigation Tests:**
7. `testISOButtonOpensSheet` — tap isoButton, verify ISO picker appears
8. `testProfileButtonOpensSheet` — tap profileButton, verify camera list appears
9. `testSettingsButtonOpensSheet` — tap settingsButton, verify settings appears

**Preview Tests:**
10. `testPreviewSwipeTogglesMode` — swipe on scenePreview, verify it changes

### Key technique for compensation dial test:
```swift
let dial = app.otherElements["compensationDial"]
let label = app.staticTexts["compensationLabel"]
let initialValue = label.label
dial.swipeLeft()
// Wait a moment for the value to update
sleep(1)
XCTAssertNotEqual(label.label, initialValue, "Compensation should change after swipe")
```

For more precise drag:
```swift
let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
start.press(forDuration: 0.1, thenDragTo: end)
```

### Affected files:
- `ZrnoUITests.swift` — all new tests go here
- `CompensationDialView.swift` — add `accessibilityIdentifier("compensationDial")` and `accessibilityIdentifier("compensationLabel")`
- Various views — verify all accessibility identifiers are in place

---

## Roadmap (NOT implementing yet)

- Film rolls: `FilmRoll` model with `Frame` children storing per-frame exposure
- Freeze settings: "hold" button locking displayed values
- Front camera metering
- Spot metering: tap preview to set metering point
- Preferred aperture setting: let user choose preferred aperture in Settings (currently hardcoded to f/8)
