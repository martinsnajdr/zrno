import SwiftUI

/// A wrapper to make Double values Identifiable for scroll position tracking.
private struct PickerItem: Identifiable, Hashable {
    let value: Double
    var id: Double { value }
}

/// Horizontal scroll-to-select picker for locked values in priority mode.
/// All values display at the same font size. Scrolling snaps to each value
/// and selects it. Tap on selected value to unlock.
struct PriorityValuePicker: View {
    @Environment(\.appTheme) private var theme

    let values: [Double]
    let selectedValue: Double
    let formatter: (Double) -> String
    let onSelect: (Double) -> Void
    var font: Font = .system(size: 15, weight: .bold, design: .monospaced)
    var onTapSelected: (() -> Void)? = nil
    var cellWidth: CGFloat = 80

    @State private var scrolledID: Double?
    @State private var isInitialized = false

    private var items: [PickerItem] {
        values.map { PickerItem(value: $0) }
    }

    var body: some View {
        GeometryReader { geo in
            let sideInset = (geo.size.width - cellWidth) / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        let isSelected = abs(item.value - selectedValue) < 0.001
                        Text(formatter(item.value))
                            .font(font)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(theme.primaryColor.opacity(isSelected ? 1.0 : 0.15))
                            .frame(minWidth: cellWidth)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelected, let onTapSelected {
                                    onTapSelected()
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        scrolledID = item.value
                                    }
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID, anchor: .center)
            .safeAreaPadding(.horizontal, sideInset)
            .scrollClipDisabled(false)
            .onChange(of: scrolledID) { _, newID in
                guard let newID, isInitialized else { return }
                if abs(newID - selectedValue) > 0.001 {
                    onSelect(newID)
                }
            }
            .onChange(of: selectedValue) { _, newValue in
                if scrolledID != newValue {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrolledID = newValue
                    }
                }
            }
            .onAppear {
                scrolledID = selectedValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitialized = true
                }
            }
        }
        .clipped()
    }
}
