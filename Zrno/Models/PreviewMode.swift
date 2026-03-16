import Foundation

/// The states of the scene preview window, cycled by horizontal swipe or tap.
enum PreviewMode: Int, CaseIterable, Codable {
    case histogram = 0
    case camera = 1
    case game = 2
    case runner = 3

    /// Modes available given current fun-mode state.
    static func available(funMode: Bool) -> [PreviewMode] {
        funMode ? allCases : [.histogram, .camera]
    }

    func next(funMode: Bool) -> PreviewMode {
        let modes = PreviewMode.available(funMode: funMode)
        guard let idx = modes.firstIndex(of: self) else { return modes.first! }
        return modes[(idx + 1) % modes.count]
    }

    func previous(funMode: Bool) -> PreviewMode {
        let modes = PreviewMode.available(funMode: funMode)
        guard let idx = modes.firstIndex(of: self) else { return modes.first! }
        return modes[(idx - 1 + modes.count) % modes.count]
    }
}
