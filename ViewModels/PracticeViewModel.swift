import Foundation
import Observation
import QuartzCore

enum NoteProgress: Equatable { case upcoming, current, clean, needsWork }

/// Drives one Alankar practice session: listens, compares to the current swar, advances, scores.
@MainActor @Observable
final class PracticeViewModel {
    let plan: SessionPlan
    let sa: SaScale
    let settings: PracticeSettings

    private(set) var progress: [NoteProgress]
    private(set) var currentIndex = 0
    private(set) var repetition = 1
    private(set) var feedback: PitchFeedback = .listening
    private(set) var cents: Double?
    private(set) var chart: [ChartSample] = []
    private(set) var clock = 0.0
    private(set) var level = 0.0
    private(set) var isPaused = false
    private(set) var micDenied = false
    private(set) var errorMessage: String?
    private(set) var message: String?
    private(set) var showHeadphoneHint = false
    private(set) var cleanTick = 0
    private(set) var missTick = 0
    private(set) var attempted = 0
    var playAlong = false

    @ObservationIgnored var onFinished: ((PracticeSession?) -> Void)?
    @ObservationIgnored private let audio = AudioEngineManager.shared
    @ObservationIgnored private let tracker: PitchTracker
    @ObservationIgnored private var results: [NoteResult] = []
    @ObservationIgnored private var started = false
    @ObservationIgnored private var finished = false
    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var ignoreUntil = 0.0
    @ObservationIgnored private var messageTask: Task<Void, Never>?

    // Per-note accumulators
    @ObservationIgnored private var noteStart = 0.0
    @ObservationIgnored private var lockClock: Double?
    @ObservationIgnored private var lastOnPitch = -10.0
    @ObservationIgnored private var streak = 0.0
    @ObservationIgnored private var released = true
    @ObservationIgnored private var voicedTime = 0.0
    @ObservationIgnored private var onPitchTime = 0.0
    @ObservationIgnored private var deviationSum = 0.0

    init(plan: SessionPlan, sa: SaScale, settings: PracticeSettings) {
        self.plan = plan
        self.sa = sa
        self.settings = settings
        tracker = PitchTracker(sa: sa, toleranceCents: settings.toleranceCents)
        progress = Self.freshProgress(count: plan.alankar.swars.count)
    }

    private static func freshProgress(count: Int) -> [NoteProgress] {
        (0..<count).map { $0 == 0 ? .current : .upcoming }
    }

    // MARK: Derived

    var swars: [Swar] { plan.alankar.swars }
    var currentSwar: Swar { swars[min(currentIndex, swars.count - 1)] }
    var totalNotes: Int { swars.count * plan.repetitions }
    var sessionFraction: Double { totalNotes == 0 ? 0 : Double(attempted) / Double(totalNotes) }
    private var beatDuration: Double { 60 / Double(max(plan.tempoBPM, 20)) }

    var rows: [ChartRow] {
        var seen = Set<Int>()
        return swars.filter { seen.insert($0.semitone).inserted }
            .sorted { $0.semitone < $1.semitone }
            .map { ChartRow(label: $0.label, semitone: Double($0.semitone)) }
    }

    // MARK: Lifecycle

    func start() async {
        guard !started else { return }
        let permission = await audio.requestPermission()
        guard permission == .granted else { micDenied = true; return }
        let accompaniment = plan.tanpuraOn || plan.tablaOn
        showHeadphoneHint = accompaniment && !audio.isHeadphonesConnected
        audio.silenceThresholdDB = showHeadphoneHint ? -35 : -45
        do { try audio.startListening() } catch { errorMessage = error.localizedDescription; return }
        audio.onFrame = { [weak self] frame in Task { @MainActor in self?.handle(frame) } }
        applyAccompaniment(true)
        started = true
        if playAlong { replayReference() }
    }

    func teardown() {
        messageTask?.cancel()
        audio.stopAll()
    }

    private func applyAccompaniment(_ on: Bool) {
        audio.synth.setTanpura(on && plan.tanpuraOn, saFrequency: sa.frequency)
        audio.synth.setTabla(on && plan.tablaOn, taal: plan.taal, bpm: Double(plan.tempoBPM))
    }

    // MARK: Controls

    func togglePause() {
        isPaused.toggle()
        applyAccompaniment(!isPaused)
        if isPaused { feedback = .listening } else { lastTimestamp = nil; tracker.reset() }
    }

    func replayReference() {
        let duration = plan.waitForNote ? 1.0 : min(0.7, beatDuration * 0.6)
        audio.synth.playReference(frequency: sa.frequency(of: currentSwar), duration: duration)
        ignoreUntil = clock + duration + 0.3
        tracker.reset()
    }

    func restart() {
        results = []
        attempted = 0
        currentIndex = 0
        repetition = 1
        progress = Self.freshProgress(count: swars.count)
        chart = []
        clock = 0
        lastTimestamp = nil
        resetNoteAccumulators()
        setMessage(nil)
    }

    func skipNote() { completeNote(forceNeedsWork: true) }

    func finish() {
        guard !finished else { return }
        finished = true
        teardown()
        guard !results.isEmpty else { onFinished?(nil); return }
        onFinished?(PracticeSession(date: .now, alankarID: plan.alankar.id, alankarName: plan.alankar.name,
                                    duration: clock, results: results))
    }

    // MARK: Frame handling

    private func handle(_ frame: PitchFrame) {
        guard started, !isPaused, !finished else { return }
        let dt = lastTimestamp.map { min(max(frame.timestamp - $0, 0), 0.2) } ?? 0
        lastTimestamp = frame.timestamp
        clock += dt
        level = max(0, min(1, Double(frame.levelDB + 60) / 40))

        let target = currentSwar
        let frequency = clock >= ignoreUntil ? frame.frequency : nil
        let out = tracker.process(frequency: frequency, target: target, now: clock)
        feedback = out.feedback
        cents = out.cents
        chart.append(ChartSample(time: clock, voice: out.voiceSemitone, target: Double(target.semitone)))
        while let first = chart.first, first.time < clock - 12 { chart.removeFirst() }

        let onPitch = out.feedback.isOnPitch
        if onPitch {
            lastOnPitch = clock
            if released {
                if lockClock == nil { lockClock = clock }
                streak += dt
            }
        } else {
            released = true
            if clock - lastOnPitch > 0.2 { streak = 0 }
        }

        let grace = min(0.25, beatDuration * 0.3)
        let measuring = plan.waitForNote ? lockClock != nil : (clock - noteStart >= grace)
        if let c = out.cents, measuring {
            voicedTime += dt
            deviationSum += abs(c) * dt
            if onPitch { onPitchTime += dt }
        }

        if plan.waitForNote {
            if streak >= settings.holdDuration { completeNote(forceNeedsWork: false) }
        } else if clock - noteStart >= beatDuration {
            completeNote(forceNeedsWork: false)
        }
    }

    private func completeNote(forceNeedsWork: Bool) {
        guard !finished, currentIndex < swars.count else { return }
        let ratio = voicedTime > 0 ? onPitchTime / voicedTime : 0
        let foundSlowly = plan.waitForNote && ((lockClock ?? clock) - noteStart) > max(3, beatDuration * 2)
        let clean = !forceNeedsWork && !foundSlowly && ratio >= settings.cleanNoteRatio && onPitchTime >= 0.2
        results.append(NoteResult(swar: swars[currentIndex], passed: clean, onPitchRatio: ratio,
                                  averageDeviationCents: voicedTime > 0 ? deviationSum / voicedTime : nil))
        attempted += 1
        progress[currentIndex] = clean ? .clean : .needsWork
        if clean {
            cleanTick += 1
            setMessage(["Beautifully sung!", "Right on the note!", "Lovely, steady swar."].randomElement())
        } else {
            missTick += 1
            setMessage("Keep going. Listen for the note and hold it steady.")
        }

        currentIndex += 1
        if currentIndex >= swars.count {
            if repetition < plan.repetitions {
                repetition += 1
                currentIndex = 0
                progress = Self.freshProgress(count: swars.count)
            } else {
                finish()
                return
            }
        } else {
            progress[currentIndex] = .current
        }
        tracker.reset()
        resetNoteAccumulators()
        released = false
        ignoreUntil = clock + 0.1
        if playAlong { replayReference() }
    }

    private func resetNoteAccumulators() {
        noteStart = clock
        lockClock = nil
        streak = 0
        voicedTime = 0
        onPitchTime = 0
        deviationSum = 0
        lastOnPitch = -10
        released = true
    }

    private func setMessage(_ text: String?) {
        messageTask?.cancel()
        message = text
        guard text != nil else { return }
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { self?.message = nil }
        }
    }
}
