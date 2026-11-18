import Foundation

/// The twelve swarasthanas. Semitone offsets are relative to the user's Sa.
enum Swar: String, CaseIterable, Identifiable, Codable, Hashable {
    case sa, reKomal, re, gaKomal, ga, ma, maTivra, pa, dhaKomal, dha, niKomal, ni

    var id: String { rawValue }

    var semitone: Int {
        switch self {
        case .sa: return 0
        case .reKomal: return 1
        case .re: return 2
        case .gaKomal: return 3
        case .ga: return 4
        case .ma: return 5
        case .maTivra: return 6
        case .pa: return 7
        case .dhaKomal: return 8
        case .dha: return 9
        case .niKomal: return 10
        case .ni: return 11
        }
    }

    var name: String {
        switch self {
        case .sa: return "Sa"
        case .reKomal, .re: return "Re"
        case .gaKomal, .ga: return "Ga"
        case .ma, .maTivra: return "Ma"
        case .pa: return "Pa"
        case .dhaKomal, .dha: return "Dha"
        case .niKomal, .ni: return "Ni"
        }
    }

    var variant: String {
        switch self {
        case .reKomal, .gaKomal, .dhaKomal, .niKomal: return "Komal"
        case .maTivra: return "Tivra"
        default: return "Shuddh"
        }
    }

    /// Short on-screen label, e.g. "Re♭" for komal Re.
    var label: String {
        switch variant {
        case "Komal": return name + "♭"
        case "Tivra": return name + "♯"
        default: return name
        }
    }

    var spokenLabel: String { variant == "Shuddh" ? name : "\(name) \(variant)" }

    static let natural: [Swar] = [.sa, .re, .ga, .ma, .pa, .dha, .ni]

    /// Grid order used by the "Build Your Alankar" screen in the Figma.
    static let builderOrder: [Swar] = [.sa, .reKomal, .re, .gaKomal, .ga, .ma, .maTivra, .pa, .dha, .dhaKomal, .niKomal, .ni]

    static func from(semitone: Int) -> Swar {
        let n = ((semitone % 12) + 12) % 12
        return allCases.first { $0.semitone == n } ?? .sa
    }

    static func parse(_ token: String) -> Swar? {
        switch token.lowercased() {
        case "sa": return .sa
        case "re": return .re
        case "ga": return .ga
        case "ma": return .ma
        case "pa": return .pa
        case "dha": return .dha
        case "ni": return .ni
        default: return nil
        }
    }
}

/// The user's detected Sa, stored as a MIDI note number.
struct SaScale: Codable, Hashable {
    var midiNote: Int
    var lowMidi: Int
    var highMidi: Int

    static let fallback = SaScale(midiNote: 58, lowMidi: 52, highMidi: 66)

    var noteName: String { MusicTheory.noteName(midi: midiNote) }
    var noteNameWithOctave: String { MusicTheory.noteNameWithOctave(midi: midiNote) }
    var frequency: Double { MusicTheory.frequency(midi: Double(midiNote)) }

    func frequency(of swar: Swar) -> Double {
        MusicTheory.frequency(midi: Double(midiNote + swar.semitone))
    }
}

enum MusicTheory {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func frequency(midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }
    static func midi(frequency: Double) -> Double { 69 + 12 * log2(frequency / 440) }
    static func noteName(midi: Int) -> String { noteNames[((midi % 12) + 12) % 12] }
    static func noteNameWithOctave(midi: Int) -> String { "\(noteName(midi: midi))\(midi / 12 - 1)" }
}

enum PitchMath {
    /// Signed cents from `target`, folded to the nearest octave (-600...600).
    /// Beginners and different voice types sing in different octaves; swar identity matters most.
    static func cents(from frequency: Double, to target: Double) -> Double {
        let raw = 1200 * log2(frequency / target)
        var folded = raw.truncatingRemainder(dividingBy: 1200)
        if folded > 600 { folded -= 1200 } else if folded < -600 { folded += 1200 }
        return folded
    }

    static func nearestSwar(frequency: Double, sa: SaScale) -> Swar {
        let semis = 12 * log2(frequency / sa.frequency)
        return Swar.from(semitone: Int(semis.rounded()))
    }
}
