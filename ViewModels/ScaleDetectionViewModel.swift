import Foundation
import Observation

@MainActor @Observable
final class ScaleDetectionViewModel {
    enum Step: Int, CaseIterable {
        case lower, upper, normal

        var subtitle: String {
            switch self {
            case .lower: return "Let’s find your lower vocal limit."
            case .upper: return "Let’s find your upper vocal limit."
            case .normal: return "Let’s find your normal vocal limit."
            }
        }
        var instructionTitle: String {
            switch self {
            case .lower: return "Sing your lowest ‘Sa’"
            case .upper: return "Sing your highest ‘Sa’"
            case .normal: return "Sing your normal ‘Sa’"
            }
        }
        var instructionBody: String {
            switch self {
            case .lower: return "Gently lower your voice to\na note that feels easy to hold"
            case .upper: return "Gently raise your voice to\na higher note that feels easy to hold"
            case .normal: return "Sing at your most\nnatural and comfortable pitch"
            }
        }
    }

    enum CaptureState: Equatable {
        case idle, listening, captured(Double), failed(String)
    }

    private(set) var step: Step = .lower
    private(set) var state: CaptureState = .idle
    private(set) var progress = 0.0
    private(set) var level = 0.0
    private(set) var micDenied = false
    private(set) var captured: [Step: Double] = [:]
    private(set) var result: SaScale?

    @ObservationIgnored private let audio = AudioEngineManager.shared
    @ObservationIgnored private var frames: [Double] = []
    @ObservationIgnored private var captureTask: Task<Void, Never>?
    private let captureDuration: TimeInterval = 3.5

    var isCaptured: Bool { if case .captured = state { return true } else { return false } }
    var isListening: Bool { state == .listening }

    var capturedNoteText: String? {
        guard case .captured(let f) = state else { return nil }
        return MusicTheory.noteNameWithOctave(midi: Int(MusicTheory.midi(frequency: f).rounded()))
    }

    func toggleCapture() {
        if isListening { cancel(); return }
        captureTask = Task { await startCapture() }
    }

    private func startCapture() async {
        let permission = await audio.requestPermission()
        guard permission == .granted else { micDenied = true; return }
        micDenied = false
        frames = []
        progress = 0
        do { try audio.startListening() } catch {
            state = .failed(error.localizedDescription)
            return
        }
        state = .listening
        audio.onFrame = { [weak self] frame in
            Task { @MainActor in self?.ingest(frame) }
        }
        let start = Date()
        while !Task.isCancelled {
            let p = Date().timeIntervalSince(start) / captureDuration
            progress = min(p, 1)
            if p >= 1 { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !Task.isCancelled else { return }
        finishCapture()
    }

    private func ingest(_ frame: PitchFrame) {
        guard isListening else { return }
        level = max(0, min(1, Double(frame.levelDB + 60) / 40))
        if let f = frame.frequency { frames.append(f) }
    }

    private func finishCapture() {
        audio.stopAll()
        level = 0
        if let f = ScaleDetectionService.steadyFrequency(from: frames) {
            captured[step] = f
            state = .captured(f)
        } else {
            state = .failed("We couldn’t hear a steady note. Try again, a little louder.")
        }
    }

    private func cancel() {
        captureTask?.cancel()
        audio.stopAll()
        level = 0
        progress = 0
        state = .idle
    }

    func retry() {
        cancel()
        captured[step] = nil
    }

    /// Moves to the next step; returns true when all three samples are done and `result` is ready.
    func advance() -> Bool {
        guard isCaptured else { return false }
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
            state = .idle
            progress = 0
            return false
        }
        if let low = captured[.lower], let high = captured[.upper], let normal = captured[.normal] {
            result = ScaleDetectionService.detectSa(low: low, high: high, normal: normal)
            return true
        }
        return false
    }

    func stop() { cancel() }
}
