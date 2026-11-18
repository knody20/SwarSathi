import Foundation

struct Alankar: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var swars: [Swar]
    var isCustom = false

    enum Difficulty: String { case easy = "Easy", medium = "Medium", hard = "Hard" }

    var sequenceText: String { swars.map(\.label).joined(separator: " ") }

    var difficulty: Difficulty {
        switch swars.count {
        case ..<6: return .easy
        case 6...8: return .medium
        default: return .hard
        }
    }

    private static func preset(_ n: Int, _ text: String) -> Alankar {
        Alankar(id: "preset-\(n)", name: "Alankar \(n)",
                swars: text.split(separator: " ").compactMap { Swar.parse(String($0)) })
    }

    /// Sequences taken from the Figma "Alankar Practice" screen.
    static let presets: [Alankar] = [
        preset(1, "Sa Re Ga Re Sa"),
        preset(2, "Sa Re Ga Ma Ga Re Sa"),
        preset(3, "Sa Sa Re Re Ga Ga"),
        preset(4, "Sa Sa Re Re Ga Ga Ma Ma"),
        preset(5, "Sa Re Ga Ma Pa Ma Ga Re Sa"),
    ]
}

/// Everything the Live Practice screen needs. Hashable so it can travel in a navigation route.
struct SessionPlan: Hashable {
    var alankar: Alankar
    var tempoBPM = 60
    var repetitions = 3
    var tanpuraOn = false
    var tablaOn = false
    var taal: Taal = .teentaal
    /// true: the highlight waits until the note is sung; false: it follows the tempo.
    var waitForNote = true
}
