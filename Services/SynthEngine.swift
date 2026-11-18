import AVFoundation

enum Taal: String, CaseIterable, Identifiable, Hashable, Codable {
    case teentaal, ektaal, jhaptaal, keharwa

    var id: String { rawValue }
    var name: String {
        switch self {
        case .teentaal: return "Teentaal"
        case .ektaal: return "Ektaal"
        case .jhaptaal: return "Jhaptaal"
        case .keharwa: return "Keharwa"
        }
    }
    var matras: Int {
        switch self {
        case .teentaal: return 16
        case .ektaal: return 12
        case .jhaptaal: return 10
        case .keharwa: return 8
        }
    }
    /// 0-based beats where each vibhag (section) starts. Beat 0 is the sam.
    var vibhagStarts: Set<Int> {
        switch self {
        case .teentaal: return [0, 4, 8, 12]
        case .ektaal: return [0, 2, 4, 6, 8, 10]
        case .jhaptaal: return [0, 2, 5, 7]
        case .keharwa: return [0, 4]
        }
    }
}

/// Small additive synth rendered in an AVAudioSourceNode: reference tones, tanpura and a taal beat.
/// The tanpura is synthesised, and the "tabla" is a pitched-click taal marker (not recorded tabla);
/// both are meant to be replaced by sampled audio later. State is read on the render thread without
/// locks - acceptable for simple flags/doubles in an MVP.
final class SynthEngine {
    private let state = SynthState()
    private var source: AVAudioSourceNode?

    var isPlaying: Bool { state.tanpuraOn || state.tablaOn || state.refSamplesLeft > 0 }
    var tanpuraOn: Bool { state.tanpuraOn }
    var tablaOn: Bool { state.tablaOn }

    func attach(to engine: AVAudioEngine, sampleRate: Double) {
        state.sampleRate = sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [state] _, _, frameCount, bufferList -> OSStatus in
            state.render(frameCount: Int(frameCount), bufferList: bufferList)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
    }

    func playReference(frequency: Double, duration: Double = 1.0) {
        state.refFrequency = frequency
        state.refTotal = max(1, Int(duration * state.sampleRate))
        state.refSamplesLeft = state.refTotal
    }

    func setTanpura(_ on: Bool, saFrequency: Double) {
        state.saFrequency = saFrequency
        if on && !state.tanpuraOn { state.tanpuraCounter = 0; state.tanpuraIndex = 0 }
        state.tanpuraOn = on
    }

    func setTabla(_ on: Bool, taal: Taal, bpm: Double) {
        state.taal = taal
        state.bpm = max(20, bpm)
        if on && !state.tablaOn { state.beatCounter = 0; state.beatIndex = 0 }
        state.tablaOn = on
    }

    func setTablaVolume(_ volume: Double) { state.tablaVolume = max(0, min(1, volume)) }

    func stopAll() {
        state.tanpuraOn = false
        state.tablaOn = false
        state.refSamplesLeft = 0
    }
}

private final class SynthState {
    var sampleRate = 44100.0

    // Reference tone
    var refFrequency = 220.0
    var refPhase = 0.0
    var refTotal = 1
    var refSamplesLeft = 0

    // Tanpura: Pa(low) - Sa - Sa - Sa(low)
    var tanpuraOn = false
    var saFrequency = 220.0
    var tanpuraCounter = 0
    var tanpuraIndex = 0
    var stringAmp = [Double](repeating: 0, count: 4)
    var stringRamp = [Double](repeating: 0, count: 4)
    var stringPhase = [Double](repeating: 0, count: 4)
    private let stringRatios = [0.75, 1.0, 1.0, 0.5]
    private let harmonicWeights: [Double] = (1...10).map { 1 / pow(Double($0), 0.9) }

    // Beat
    var tablaOn = false
    var taal: Taal = .teentaal
    var bpm = 60.0
    var tablaVolume = 0.6
    var beatCounter = 0
    var beatIndex = 0
    var clickAmp = 0.0
    var clickDecay = 0.999
    var clickFreq = 200.0
    var clickPhase = 0.0

    func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let first = buffers.first, let out = first.mData?.assumingMemoryBound(to: Float.self) else { return }
        for i in 0..<frameCount { out[i] = Float(nextSample()) }
        if buffers.count > 1 {
            for b in 1..<buffers.count {
                if let dst = buffers[b].mData?.assumingMemoryBound(to: Float.self) {
                    dst.update(from: out, count: frameCount)
                }
            }
        }
    }

    private func nextSample() -> Double {
        var s = 0.0
        if refSamplesLeft > 0 {
            let t = 1 - Double(refSamplesLeft) / Double(max(refTotal, 1))
            let env = min(1, t * 30) * min(1, (1 - t) * 15)
            s += env * 0.22 * (sin(refPhase) + 0.35 * sin(2 * refPhase) + 0.12 * sin(3 * refPhase))
            refPhase += 2 * .pi * refFrequency / sampleRate
            if refPhase > 2 * .pi { refPhase -= 2 * .pi }
            refSamplesLeft -= 1
        }
        if tanpuraOn { s += tanpuraSample() }
        if tablaOn { s += beatSample() }
        return max(-0.95, min(0.95, s))
    }

    private func tanpuraSample() -> Double {
        if tanpuraCounter <= 0 {
            stringAmp[tanpuraIndex] = 1
            stringRamp[tanpuraIndex] = 0
            tanpuraIndex = (tanpuraIndex + 1) % 4
            tanpuraCounter = Int(sampleRate * 0.95)
        }
        tanpuraCounter -= 1
        let decay = exp(-1 / (sampleRate * 2.8))
        var out = 0.0
        for n in 0..<4 where stringAmp[n] > 0.0005 {
            var v = 0.0
            for k in 0..<harmonicWeights.count {
                v += harmonicWeights[k] * sin(Double(k + 1) * stringPhase[n])
            }
            stringRamp[n] = min(1, stringRamp[n] + 1 / (0.012 * sampleRate))
            out += stringAmp[n] * stringRamp[n] * v * 0.11
            stringPhase[n] += 2 * .pi * saFrequency * stringRatios[n] / sampleRate
            if stringPhase[n] > 2 * .pi { stringPhase[n] -= 2 * .pi }
            stringAmp[n] *= decay
        }
        return out
    }

    private func beatSample() -> Double {
        if beatCounter <= 0 {
            let isSam = beatIndex == 0
            let isVibhag = taal.vibhagStarts.contains(beatIndex)
            clickFreq = isSam ? 110 : (isVibhag ? 190 : 300)
            clickAmp = isSam ? 1.0 : (isVibhag ? 0.7 : 0.45)
            clickDecay = isSam ? 0.9995 : 0.999
            clickPhase = 0
            beatIndex = (beatIndex + 1) % taal.matras
            beatCounter = Int(sampleRate * 60 / bpm)
        }
        beatCounter -= 1
        guard clickAmp > 0.001 else { return 0 }
        clickPhase += 2 * .pi * clickFreq * (1 + 0.6 * clickAmp) / sampleRate
        if clickPhase > 2 * .pi { clickPhase -= 2 * .pi }
        let v = sin(clickPhase) * clickAmp * tablaVolume * 0.5
        clickAmp *= clickDecay
        return v
    }
}
