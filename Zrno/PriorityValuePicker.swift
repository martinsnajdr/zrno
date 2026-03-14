import SwiftUI

/// Preference key to report each item's center X in the scroll coordinate space.
private struct ItemCenterKey: PreferenceKey {
    static let defaultValue: [Double: CGFloat] = [:]
    static func reduce(value: inout [Double: CGFloat], nextValue: () -> [Double: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Horizontal scroll-to-select picker for locked values in priority mode.
/// When `isLocked` is false, only the selected value is visible (like a plain label).
/// When `isLocked` is true, neighboring values fade in and the picker becomes scrollable.
struct PriorityValuePicker: View {
    @Environment(\.appTheme) private var theme

    let values: [Double]
    let selectedValue: Double
    let formatter: (Double) -> String
    let onSelect: (Double) -> Void
    var font: Font = .system(size: 15, weight: .bold, design: .monospaced)
    var isLocked: Bool = false
    var onTap: () -> Void = {}

    @State private var isInitialized = false
    @State private var centers: [Double: CGFloat] = [:]

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(values, id: \.self) { value in
                            let isSelected = value == selectedValue || (selectedValue != 0 && abs(value - selectedValue) / abs(selectedValue) < 0.001)
                            Text(formatter(value))
                                .font(font)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(
                                    isSelected
                                        ? theme.primaryColor.opacity(isLocked ? 1.0 : 0.85)
                                        : theme.primaryColor.opacity(isLocked ? 0.15 : 0)
                                )
                                .contentShape(Rectangle())
                                .id(value)
                                .background(
                                    GeometryReader { itemGeo in
                                        Color.clear
                                            .preference(
                                                key: ItemCenterKey.self,
                                                value: [value: itemGeo.frame(in: .named("picker")).midX]
                                            )
                                    }
                                )
                                .onTapGesture {
                                    if isSelected {
                                        onTap()
                                    } else if isLocked {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo(value, anchor: .center)
                                        }
                                        onSelect(value)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, halfWidth)
                    .frame(height: geo.size.height)
                }
                .scrollDisabled(!isLocked)
                .coordinateSpace(name: "picker")
                .onPreferenceChange(ItemCenterKey.self) { newCenters in
                    centers = newCenters
                }
                .onScrollPhaseChange { _, newPhase in
                    guard isInitialized, isLocked else { return }
                    if newPhase == .idle {
                        snapToNearest(proxy: proxy, viewportCenter: halfWidth)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedValue, anchor: .center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitialized = true
                    }
                }
                .onChange(of: selectedValue) { _, newValue in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLocked)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: isLocked ? 32 : 0)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: isLocked ? 32 : 0)
            }
        )
    }

    private func snapToNearest(proxy: ScrollViewProxy, viewportCenter: CGFloat) {
        guard !centers.isEmpty else { return }
        let closest = centers.min(by: {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        })
        guard let closest else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(closest.key, anchor: .center)
        }
        if closest.key != selectedValue {
            onSelect(closest.key)
        }
    }
}
