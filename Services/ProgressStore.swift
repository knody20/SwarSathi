import Foundation
import Observation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let lockedTitle: String
    let symbol: String
    let unlocked: Bool
}

@MainActor @Observable
final class ProgressStore {
    private(set) var profile = UserProfile()
    private(set) var settings = PracticeSettings()
    private(set) var sessions: [PracticeSession] = []
    private(set) var customAlankars: [Alankar] = []

    private struct Snapshot: Codable {
        var profile: UserProfile
        var settings: PracticeSettings
        var sessions: [PracticeSession]
        var customAlankars: [Alankar]
    }
    private let key = "swarsathi.snapshot.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        profile = snap.profile
        settings = snap.settings
        sessions = snap.sessions
        customAlankars = snap.customAlankars
    }

    private func persist() {
        let snap = Snapshot(profile: profile, settings: settings, sessions: sessions, customAlankars: customAlankars)
        if let data = try? JSONEncoder().encode(snap) { UserDefaults.standard.set(data, forKey: key) }
    }

    // MARK: Mutations

    func updateProfile(_ change: (inout UserProfile) -> Void) { change(&profile); persist() }
    func updateSettings(_ change: (inout PracticeSettings) -> Void) { change(&settings); persist() }
    func add(_ session: PracticeSession) { sessions.append(session); persist() }

    func saveAlankar(swars: [Swar]) {
        let number = customAlankars.count + 1
        customAlankars.append(Alankar(id: "custom-\(UUID().uuidString)", name: "My Alankar \(number)", swars: swars, isCustom: true))
        persist()
    }
    func deleteAlankar(_ alankar: Alankar) {
        customAlankars.removeAll { $0.id == alankar.id }
        persist()
    }

    // MARK: Derived

    var saScale: SaScale { profile.saScale ?? .fallback }
    var allAlankars: [Alankar] { Alankar.presets + customAlankars }

    func nextAlankar(after alankar: Alankar) -> Alankar {
        let all = allAlankars
        guard let i = all.firstIndex(where: { $0.id == alankar.id }) else { return all[0] }
        return all[(i + 1) % all.count]
    }

    var recentSessions: [PracticeSession] { sessions.sorted { $0.date > $1.date } }

    var averageAccuracy: Double {
        sessions.isEmpty ? 0 : sessions.map(\.accuracy).reduce(0, +) / Double(sessions.count)
    }

    private var practiceDays: [Date] {
        let cal = Calendar.current
        return Set(sessions.map { cal.startOfDay(for: $0.date) }).sorted()
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let days = Set(practiceDays)
        var day = cal.startOfDay(for: .now)
        if !days.contains(day), let yesterday = cal.date(byAdding: .day, value: -1, to: day) { day = yesterday }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var longestStreak: Int {
        let cal = Calendar.current
        var best = 0, run = 0
        var previous: Date?
        for day in practiceDays {
            if let p = previous, cal.date(byAdding: .day, value: 1, to: p) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        return best
    }

    var achievements: [Achievement] {
        [
            Achievement(id: "first", title: "First Riyaaz", lockedTitle: "First Riyaaz", symbol: "mic.fill", unlocked: !sessions.isEmpty),
            Achievement(id: "streak5", title: "5-Day Streak", lockedTitle: "5-Day Streak", symbol: "calendar", unlocked: longestStreak >= 5),
            Achievement(id: "ten", title: "10 Sessions", lockedTitle: "10 Sessions", symbol: "star.fill", unlocked: sessions.count >= 10),
            Achievement(id: "twentyfive", title: "25 Sessions", lockedTitle: "Keep Practising", symbol: "lock.fill", unlocked: sessions.count >= 25),
        ]
    }

    func sessions(for alankarID: String) -> [PracticeSession] {
        sessions.filter { $0.alankarID == alankarID }.sorted { $0.date < $1.date }
    }

    /// An alankar built around the swars the user misses most; falls back to Alankar 2 without history.
    func focusedAlankar() -> Alankar {
        var misses: [Swar: Int] = [:]
        for result in sessions.flatMap(\.results) where !result.passed { misses[result.swar, default: 0] += 1 }
        let weak = misses.sorted { $0.value > $1.value }.map(\.key).filter { $0 != .sa }.prefix(3)
        guard !weak.isEmpty else { return Alankar.presets[1] }
        let ordered = weak.sorted { $0.semitone < $1.semitone }
        let sequence = [Swar.sa] + ordered + ordered.reversed() + [Swar.sa]
        return Alankar(id: "focused", name: "Focused Session", swars: sequence)
    }
}
