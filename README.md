# Zrno — Film Camera Companion

A precise light meter for analog photography. Zrno uses your iPhone camera to measure light and recommends aperture/shutter speed combinations tailored to your specific film camera.

## Features

- **Real-time EV metering** — measures ambient light via the iPhone camera
- **Custom camera profiles** — set your exact apertures and shutter speeds so every recommendation is one you can dial in
- **Multiple lenses per camera** — each with its own aperture range
- **Aperture & shutter priority modes** — lock one value, Zrno solves the other
- **Exposure compensation** — ±3 EV in 1/3 stop increments
- **Exposure table** — see all valid combinations at a glance
- **Live histogram** — 256-bin luminance histogram with temporal smoothing
- **Pixelated camera preview** — lo-fi 36×24 monochrome preview in your chosen color scheme
- **Pinhole camera support** — enter diameter and focal length, select a film stock, get Schwarzschild-corrected exposure times
- **Film stock presets** — HP5+, Tri-X, FP4+, Delta 100/400/3200, T-Max, Acros, Fomapan, and more
- **Shutter speed calibration** — compensate for aging shutters
- **Multi-camera support** — switch between ultra-wide, wide, and telephoto iPhone lenses

## Appearance

4 color schemes, 4 font options, light/dark/system modes. Every pixel is themed.

| Scheme | Description |
|--------|-------------|
| Midnight Noir | Dark, high contrast |
| Vintage Cream | Warm, paper-like |
| Frosty Steel | Cool, metallic |
| Darkroom Red | Safelight aesthetic |

## Tech Stack

- **SwiftUI** + **SwiftData**
- `@Observable` architecture (no Combine)
- `AVCaptureSession` for light metering via exposure metadata
- Pure Swift exposure math (no third-party dependencies)
- Zero network requests, zero analytics, zero tracking

## Requirements

- iOS 17.0+
- Xcode 15.0+
- iPhone with camera (uses exposure metadata for metering)

## Building

```
git clone https://github.com/your-username/zrno.git
cd zrno
open Zrno.xcodeproj
```

Select your device or simulator and build with `Cmd+R`. Camera metering requires a physical device; the simulator uses a fallback EV value.

## Project Structure

```
Zrno/
├── App/                    # Entry point, theme, main content view
├── Models/                 # CameraProfile, Lens, ExposureCalculator, PreviewMode
├── Services/               # LightMeterService (AVCapture + EV computation)
├── Games/                  # Hidden pixel games (Fun Mode)
└── Views/
    ├── Meter/              # Main metering UI, histogram, preview, dials
    ├── Profiles/           # Camera & lens editors
    └── Settings/           # Settings, documentation, appearance
```

## Privacy

Zrno does not collect any data. The camera is used solely to read exposure metadata for light measurement — no images are captured, stored, or transmitted. All user data (camera profiles, settings) stays on-device.

## License

All rights reserved.
