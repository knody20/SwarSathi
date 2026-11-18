import Foundation

struct NoteResult: Codable, Hashable, Identifiable {
    var id = UUID()
    let swar: Swar
    /// "Clean": held steadily on pitch and found without long searching.
    let passed: Bool
    let onPitchRatio: Double
    let averageDeviationCents: Double?
}

struct PracticeSession: Codable, Hashable, Identifiable {
    var id = UUID()
    let date: Date
    let alankarID: String
    let alankarName: String
    let duration: TimeInterval
    let results: [NoteResult]

    var totalNotes: Int { results.count }
    var notesOnPitch: Int { results.filter(\.passed).count }
    var accuracy: Double { totalNotes == 0 ? 0 : Double(notesOnPitch) / Double(totalNotes) }

    var weakSwars: [Swar] {
        var seen = Set<Swar>()
        return results.filter { !$0.passed }.map(\.swar).filter { seen.insert($0).inserted }
    }
}

struct UserProfile: Codable, Equatable {
    var name = "Friend"
    var isSignedIn = false
    var saScale: SaScale?
}

struct PracticeSettings: Codable, Equatable {
    /// Half-width of the "on pitch" window, in cents.
    var toleranceCents = 35.0
    /// How long a note must be held to count (wait-for-note mode).
    var holdDuration = 0.5
    /// Share of measured time that must be on pitch for a note to count as clean.
    var cleanNoteRatio = 0.6
}
