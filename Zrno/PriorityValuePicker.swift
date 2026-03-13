import SwiftUI

/// Horizontal scrollable picker for selecting a locked value in priority mode.
/// Shows available apertures or shutter speeds as tappable chips.
struct PriorityValuePicker: View {
    @Environment(\.appTheme) private var theme

    let values: [Double]
    let selectedValue: Double
    let formatter: (Double) -> String
    let onSelect: (Double) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        let isSelected = abs(value - selectedValue) < 0.001
                        Button {
                            onSelect(value)
                        } label: {
                            Text(formatter(value))
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundStyle(isSelected ? theme.primaryColor : theme.secondaryColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected
                                        ? theme.accentColor.opacity(0.2)
                                        : theme.primaryColor.opacity(0.05),
                                    in: Capsule()
                                )
                                .overlay(
                                    isSelected
                                        ? Capsule().stroke(theme.accentColor.opacity(0.4), lineWidth: 1)
                                        : nil
                                )
                        }
                        .id(value)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                proxy.scrollTo(selectedValue, anchor: .center)
            }
            .onChange(of: selectedValue) { _, newValue in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 36)
    }
}
