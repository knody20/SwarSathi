import AVFoundation
import Accelerate
import Observation

enum MicrophonePermission { case undetermined, granted, denied }

struct PitchFrame: Sendable {
    let timestamp: TimeInterval
    /// nil when silent, noisy or unvoiced.
    let frequency: Double?
    let clarity: Double
    let levelDB: Float
}

enum AudioEngineError: LocalizedError {
    case permissionDenied, noInput
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone access is turned off."
        case .noInput: return "No microphone input is available."
        }
    }
}

/// Owns the single AVAudioEngine: microphone tap -> YIN -> PitchFrame, plus the synth used for
/// reference tones, tanpura and beat. Deliberately knows nothing about SwiftUI or practice logic.
@Observable
final class AudioEngineManager {
    static let shared = AudioEngineManager()

    private(set) var permission: MicrophonePermission = .undetermined
    private(set) var isListening = false

    @ObservationIgnored var onFrame: (@Sendable (PitchFrame) -> Void)?
    /// Frames quieter than this are treated as silence (background-noise gate).
    @ObservationIgnored var silenceThresholdDB: Float = -45
    @ObservationIgnored let synth = SynthEngine()

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let queue = DispatchQueue(label: "swarsathi.pitch", qos: .userInitiated)
    @ObservationIgnored private var detector: YINPitchDetector?
    @ObservationIgnored private var window: [Float] = []
    @ObservationIgnored private let windowSize = 4096
    @ObservationIgnored private var synthAttached = false

    init() { refreshPermission() }

    // MARK: Permission

    func refreshPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permission = .granted
        case .denied: permission = .denied
        default: permission = .undetermined
        }
    }

    func requestPermission() async -> MicrophonePermission {
        refreshPermission()
        if permission == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            permission = granted ? .granted : .denied
        }
        return permission
    }

    var isHeadphonesConnected: Bool {
        let ports: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { ports.contains($0.portType) }
    }

    // MARK: Engine

    /// Output only (tanpura / beat preview) - does not touch the microphone.
    func startOutput() throws {
        try configureSession()
        attachSynthIfNeeded()
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    func startListening() throws {
        guard permission == .granted else { throw AudioEngineError.permissionDenied }
        try configureSession()
        attachSynthIfNeeded()
        if engine.isRunning { engine.stop() }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioEngineError.noInput }

        detector = YINPitchDetector(sampleRate: format.sampleRate)
        queue.sync { window.removeAll() }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
        isListening = true
    }

    /// Stops the microphone, the engine and every synth voice.
    func stopAll() {
        onFrame = nil
        synth.stopAll()
        if isListening { engine.inputNode.removeTap(onBus: 0) }
        engine.stop()
        isListening = false
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .measurement turns off automatic gain / voice processing, which is what pitch tracking wants.
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func attachSynthIfNeeded() {
        guard !synthAttached else { return }
        let rate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        synth.attach(to: engine, sampleRate: rate > 0 ? rate : 44100)
        synthAttached = true
    }

    // MARK: Analysis

    private func handle(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        queue.async { [weak self] in self?.analyse(chunk) }
    }

    private func analyse(_ chunk: [Float]) {
        guard !chunk.isEmpty else { return }
        window.append(contentsOf: chunk)
        if window.count > windowSize { window.removeFirst(window.count - windowSize) }

        var rms: Float = 0
        vDSP_rmsqv(chunk, 1, &rms, vDSP_Length(chunk.count))
        let db = 20 * log10(max(rms, 1e-7))

        var estimate: PitchEstimate?
        if window.count >= windowSize, db > silenceThresholdDB {
            estimate = detector?.estimate(samples: window)
        }
        let frame = PitchFrame(timestamp: CACurrentMediaTime(),
                               frequency: estimate?.frequency,
                               clarity: estimate?.clarity ?? 0,
                               levelDB: db)
        onFrame?(frame)
    }
}
