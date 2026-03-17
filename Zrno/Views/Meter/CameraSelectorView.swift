import SwiftUI

struct CameraSelectorView: View {
    @Environment(\.appTheme) private var theme

    let cameras: [CameraLens]
    let activeCameraID: String
    let onSelect: (CameraLens) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(cameras) { lens in
                Button {
                    onSelect(lens)
                } label: {
                    Text(lens.label)
                        .font(.system(size: 12, weight: lens.id == activeCameraID ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(lens.id == activeCameraID ? theme.primaryColor : theme.secondaryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            lens.id == activeCameraID
                                ? theme.primaryColor.opacity(0.12)
                                : theme.primaryColor.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
