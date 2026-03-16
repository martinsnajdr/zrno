import SwiftUI

struct DocumentationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @AppStorage("zrno.funMode") private var funMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                docSection("Disclaimer") {
                    docText("Zrno uses your **iPhone camera sensor** to measure light. Accuracy depends on your **device model**, its calibration, and environmental conditions. Results are **approximate** and may vary between devices. Always **bracket important shots**. This app is a metering aid, not a replacement for a dedicated light meter.")
                }

                docSection("Light Metering") {
                    docText("The app reads exposure values from the iPhone camera and recommends **aperture and shutter speed** combinations for your film camera. The exposure display updates in **real time** as lighting changes.")
                    docText("Status messages indicate the current state:")
                    docBullet("CORRECT EXPOSURE", "A valid combination exists within your camera's range.")
                    docBullet("UNDEREXPOSED", "The scene is too dark for your equipment's aperture and shutter speed range.")
                    docBullet("OVEREXPOSED", "The scene is too bright for your equipment's range.")
                    docBullet("UNRELIABLE", "The iPhone sensor is near its own limits. Readings may be inaccurate in very low or very bright light.")
                }

                docSection("Priority Modes") {
                    docText("**Tap** the aperture or shutter speed value to **lock** it. The app then calculates the other value to achieve correct exposure.")
                    docBullet("Aperture Priority", "Lock an **f-stop**, shutter speed adjusts automatically.")
                    docBullet("Shutter Priority", "Lock a **shutter speed**, aperture adjusts automatically.")
                    docText("When locked, **swipe left or right** on the value to change it. **Tap again** to unlock and return to auto mode.")
                }

                docSection("Exposure Compensation") {
                    docText("The dial below the exposure values adjusts compensation in **1/3 stop** increments. Use this to intentionally over- or underexpose, for example when shooting **backlit subjects** or **snow scenes**.")
                }

                docSection("Camera Profiles") {
                    docText("Each profile defines the **aperture and shutter speed range** of a specific camera. The app only recommends values your camera actually supports.")
                    docText("The built-in **Basic** profile covers a general range. Create **custom profiles** for your cameras with their exact aperture and shutter speed values.")
                    docText("Profiles can have **multiple lenses**, each with its own aperture range. **Swipe** the lens name to switch between them.")
                    docText("You can also calibrate individual shutter speeds if your camera's actual speeds differ from the nominal values.")
                    docText("For **pinhole cameras**, set the profile type to Pinhole. This uses a **fixed aperture** value and applies **Schwarzschild reciprocity correction** for long exposures. Set the **p-factor** matching your film stock to get corrected exposure times. The uncorrected time is shown alongside for reference.")
                }

                docSection("Preview & Histogram") {
                    docText("The **pixelated preview** shows a simplified view of the scene with light and dark areas clearly visible. Use it to check the **tonal distribution** of your composition — where the highlights fall, where the shadows sit, and whether contrast is even or concentrated. It is not meant to be sharp; the low resolution is intentional to focus on **light, not detail**.")
                    docText("The **histogram** shows the luminance distribution across the scene as a bar graph from shadows (left) to highlights (right). Use it to spot **clipped highlights** or **crushed shadows** before you shoot.")
                    docText("**Tap or swipe** to switch between the preview and the histogram.")
                }

                if funMode {
                    docSection("Hidden Games") {
                        docText("Yes, there are two games hidden in a light meter app. No, we don't know why either. Somewhere between calibrating shutter speeds and arguing about reciprocity failure, we thought: **what if you could also play Arkanoid?** And then, because one inexplicable game wasn't enough: **a runner game too.**")
                        docText("**Swipe** past the histogram and camera preview to find them. They live in the same tiny pixel grid because apparently **36x24 pixels** is all you need for entertainment.")
                        docBullet("Zrnoid", "Tilt your phone to move the paddle. Tap to launch. Try not to drop the ball — your film camera is watching and judging you.")
                        docBullet("Zrnorun", "Tap to jump. That's it. A photographer runs endlessly over obstacles, much like your quest for the perfect exposure.")
                        docText("High scores are saved. Bragging rights are yours to claim. **No film was harmed** in the making of these games.")
                    }
                }

                docSection("iPhone Camera Selection") {
                    docText("If your iPhone has **multiple rear cameras**, you can switch between them. The app **automatically selects** the closest focal length when you switch lenses in a profile.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(theme.backgroundColor)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            ZStack {
                Text("GUIDE")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(theme.primaryColor)

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryColor)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(theme.primaryColor.opacity(theme.subtleOpacity))
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.backgroundColor)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [theme.backgroundColor, theme.backgroundColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 6)
                .offset(y: 6)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Components

    private func docSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.secondaryColor)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(theme.subtleOpacity))
            )
        }
    }

    private func docText(_ markdown: String) -> some View {
        Text(makeAttributed(markdown))
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.primaryColor.opacity(0.85))
    }

    private func docBullet(_ label: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.primaryColor)
            Text(makeAttributed("**\(label)** — \(description)"))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.primaryColor.opacity(0.85))
        }
    }

    /// Parse **bold** markers into an AttributedString
    private func makeAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

#Preview {
    NavigationStack {
        DocumentationView()
    }
    .preferredColorScheme(.dark)
}
