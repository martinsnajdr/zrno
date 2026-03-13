import Foundation

/// The two states of the scene preview window, cycled by horizontal swipe or tap.
enum PreviewMode: Int, CaseIterable, Codable {
    case histogram = 0
    case camera = 1

    var next: PreviewMode {
        let all = PreviewMode.allCases
        let idx = (rawValue + 1) % all.count
        return all[idx]
    }

    var previous: PreviewMode {
        let all = PreviewMode.allCases
        let idx = (rawValue - 1 + all.count) % all.count
        return all[idx]
    }
}
