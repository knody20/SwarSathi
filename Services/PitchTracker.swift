import Foundation

enum PitchFeedback: Equatable {
    case listening, onPitch, sharp(Double), flat(Double), otherNote(Swar)

    enum Tone { case neutral, good, caution, off }

    var tone: Tone {
        switch self {
        case .listening: return .neutral
        case .onPitch: return .good
        case .sharp, .flat: return .caution
        case .otherNote: return .off
        }
    }
    var title: String {
        switch self {
        case .listening: return "Listening…"
        case .onPitch: return "On pitch"
        case .sharp: return "Slightly sharp"
        case .flat: return "Slightly flat"
        case .otherNote(let s): return "That was \(s.label)"
        }
    }
    /// Shape + text + colour together, so accuracy never relies on colour alone.
    var symbol: String {
        switch self {
        case .listening: return "waveform"
        case .onPitch: return "checkmark.circle.fill"
        case .sharp: return "arrow.up.circle.fill"
        case .flat: return "arrow.down.circle.fill"
        case .otherNote: return "xmark.circle.fill"
        }
    }
    var isOnPitch: Bool { if case .onPitch = self { return true } else { return false } }
}

/// Smooths raw frequency readings and classifies them against a target swar.
final class PitchTracker {
    struct Output {
        let feedback: PitchFeedback
        let cents: Double?
        /// Semitones above Sa (octave-folded near the target) for plotting.
        let voiceSemitone: Double?
    }

    private let sa: SaScale
    var toleranceCents: Double
    private var smoothed: Double?
    private var lastVoiced: TimeInterval = -10

    init(sa: SaScale, toleranceCents: Double) {
        self.sa = sa
        self.toleranceCents = toleranceCents
    }

    func reset() { smoothed = nil }

    func process(frequency: Double?, target: Swar, now: TimeInterval) -> Output {
        guard let frequency else {
            if now - lastVoiced > 0.35 { smoothed = nil }
            return Output(feedback: .listening, cents: nil, voiceSemitone: nil)
        }
        lastVoiced = now
        let raw = PitchMath.cents(from: frequency, to: sa.frequency(of: target))
        let value: Double
        if let previous = smoothed, abs(raw - previous) < 150 {
            value = previous + 0.45 * (raw - previous)
        } else {
            value = raw
        }
        smoothed = value

        let feedback: PitchFeedback
        if abs(value) <= toleranceCents {
            feedback = .onPitch
        } else if value > toleranceCents && value <= 100 {
            feedback = .sharp(value)
        } else if value < -toleranceCents && value >= -100 {
            feedback = .flat(value)
        } else {
            feedback = .otherNote(PitchMath.nearestSwar(frequency: frequency, sa: sa))
        }
        return Output(feedback: feedback, cents: value, voiceSemitone: Double(target.semitone) + value / 100)
    }
}
