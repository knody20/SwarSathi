import Foundation

enum ScaleDetectionService {
    /// Median frequency of a held note, or nil if the voice wasn't steady enough.
    static func steadyFrequency(from frequencies: [Double], minimumFrames: Int = 10, toleranceSemitones: Double = 1.5) -> Double? {
        guard frequencies.count >= minimumFrames else { return nil }
        let midis = frequencies.map { MusicTheory.midi(frequency: $0) }.sorted()
        let median = midis[midis.count / 2]
        let stable = midis.filter { abs($0 - median) <= toleranceSemitones }
        guard stable.count >= minimumFrames, Double(stable.count) / Double(midis.count) >= 0.5 else { return nil }
        return MusicTheory.frequency(midi: stable.sorted()[stable.count / 2])
    }

    /// Sa is the note the user sang as their "normal Sa", kept inside their measured range.
    static func detectSa(low: Double, high: Double, normal: Double) -> SaScale {
        let lowMidi = Int(MusicTheory.midi(frequency: low).rounded())
        let highMidi = Int(MusicTheory.midi(frequency: high).rounded())
        var sa = Int(MusicTheory.midi(frequency: normal).rounded())
        let lo = min(lowMidi, highMidi), hi = max(lowMidi, highMidi)
        sa = min(max(sa, lo), hi)
        return SaScale(midiNote: sa, lowMidi: lo, highMidi: hi)
    }
}
