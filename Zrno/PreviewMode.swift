import Foundation

/// The three states of the scene preview window, cycled by horizontal swipe.
enum PreviewMode: Int, CaseIterable, Codable {
    case hidden = 0
    case camera = 1
    case histogram = 2

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
