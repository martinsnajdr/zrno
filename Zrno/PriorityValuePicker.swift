import SwiftUI

/// Preference key to report each item's center X in the scroll coordinate space.
private struct ItemCenterKey: PreferenceKey {
    static let defaultValue: [Double: CGFloat] = [:]
    static func reduce(value: inout [Double: CGFloat], nextValue: () -> [Double: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Horizontal scroll-to-select picker for locked values in priority mode.
/// Variable-width cells. Whichever item's center is closest to the viewport
/// center when scrolling stops gets selected (magnet behavior).
struct PriorityValuePicker: View {
    @Environment(\.appTheme) private var theme

    let values: [Double]
    let selectedValue: Double
    let formatter: (Double) -> String
    let onSelect: (Double) -> Void
    var font: Font = .system(size: 15, weight: .bold, design: .monospaced)
    var onTapSelected: (() -> Void)? = nil

    @State private var isInitialized = false
    @State private var centers: [Double: CGFloat] = [:]
    @State private var viewportCenter: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(values, id: \.self) { value in
                            let isSelected = abs(value - selectedValue) < 0.001
                            Text(formatter(value))
                                .font(font)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(theme.primaryColor.opacity(isSelected ? 1.0 : 0.15))
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
                                    if isSelected, let onTapSelected {
                                        onTapSelected()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo(value, anchor: .center)
                                        }
                                        onSelect(value)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, halfWidth)
                }
                .coordinateSpace(name: "picker")
                .onPreferenceChange(ItemCenterKey.self) { newCenters in
                    centers = newCenters
                }
                .onScrollPhaseChange { _, newPhase in
                    guard isInitialized else { return }
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
        .clipped()
    }

    private func snapToNearest(proxy: ScrollViewProxy, viewportCenter: CGFloat) {
        guard !centers.isEmpty else { return }
        let closest = centers.min(by: {
            abs($0.value - viewportCenter) < abs($1.value - viewportCenter)
        })
        guard let closest, abs(closest.key - selectedValue) > 0.001 else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(closest.key, anchor: .center)
        }
        onSelect(closest.key)
    }
}
