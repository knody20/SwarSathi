import Foundation
import Observation
import QuartzCore

/// Microphone -> feedback + chart history for a single target swar (Swar Abhyas) or for free singing
/// (Open Riyaz, where `target == nil` and the nearest swar is detected).
@MainActor @Observable
final class LivePitchListener {
    private(set) var feedback: PitchFeedback = .listening
    private(set) var chart: [ChartSample] = []
    private(set) var clock = 0.0
    private(set) var level = 0.0
    private(set) var detectedSwar: Swar?
    private(set) var cents: Double?
    private(set) var micDenied = false
    private(set) var errorMessage: String?
    var target: Swar?
    private(set) var tanpuraOn = false

    let sa: SaScale
    @ObservationIgnored private let audio = AudioEngineManager.shared
    @ObservationIgnored private let tracker: PitchTracker
    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var ignoreUntil = 0.0
    @ObservationIgnored private var lastTarget: Swar = .sa

    init(sa: SaScale, settings: PracticeSettings, target: Swar?) {
        self.sa = sa
        self.target = target
        tracker = PitchTracker(sa: sa, toleranceCents: settings.toleranceCents)
        if let target { lastTarget = target }
    }

    func start() async {
        let permission = await audio.requestPermission()
        guard permission == .granted else { micDenied = true; return }
        do { try audio.startListening() } catch { errorMessage = error.localizedDescription; return }
        audio.silenceThresholdDB = tanpuraOn && !audio.isHeadphonesConnected ? -35 : -45
        audio.onFrame = { [weak self] frame in Task { @MainActor in self?.handle(frame) } }
        applyTanpura()
    }

    func stop() { audio.stopAll() }

    func select(_ swar: Swar) {
        target = swar
        lastTarget = swar
        tracker.reset()
        playReference(swar)
    }

    func playReference(_ swar: Swar) {
        audio.synth.playReference(frequency: sa.frequency(of: swar), duration: 1.0)
        ignoreUntil = clock + 1.3
    }

    func setTanpura(_ on: Bool) {
        tanpuraOn = on
        applyTanpura()
    }

    private func applyTanpura() { audio.synth.setTanpura(tanpuraOn, saFrequency: sa.frequency) }

    private func handle(_ frame: PitchFrame) {
        let dt = lastTimestamp.map { min(max(frame.timestamp - $0, 0), 0.2) } ?? 0
        lastTimestamp = frame.timestamp
        clock += dt
        level = max(0, min(1, Double(frame.levelDB + 60) / 40))

        let frequency = clock >= ignoreUntil ? frame.frequency : nil
        let resolved: Swar
        if let target { resolved = target }
        else if let f = frequency { resolved = PitchMath.nearestSwar(frequency: f, sa: sa) }
        else { resolved = lastTarget }
        lastTarget = resolved

        let out = tracker.process(frequency: frequency, target: resolved, now: clock)
        feedback = out.feedback
        cents = out.cents
        detectedSwar = frequency == nil ? nil : resolved
        chart.append(ChartSample(time: clock, voice: out.voiceSemitone, target: Double(resolved.semitone)))
        while let first = chart.first, first.time < clock - 12 { chart.removeFirst() }
    }
}
