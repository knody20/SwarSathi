import Accelerate
import Foundation

struct PitchEstimate {
    let frequency: Double
    /// 0...1, higher means a clearer periodic (voiced) signal.
    let clarity: Double
}

/// YIN fundamental-frequency estimator (de Cheveigné & Kawahara, 2002).
/// Independent of the UI and of AVFoundation, so it can be unit-tested with synthetic sine waves.
final class YINPitchDetector {
    private let sampleRate: Double
    private let minFrequency: Double
    private let maxFrequency: Double
    private let threshold: Float

    init(sampleRate: Double, minFrequency: Double = 70, maxFrequency: Double = 1000, threshold: Float = 0.15) {
        self.sampleRate = sampleRate
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
    }

    func estimate(samples: [Float]) -> PitchEstimate? {
        let tauMax = min(samples.count / 2 - 1, Int(sampleRate / minFrequency))
        let tauMin = max(2, Int(sampleRate / maxFrequency))
        guard tauMax > tauMin + 2 else { return nil }
        let window = samples.count - tauMax

        // 1. Difference function d(tau) = sum (x[j] - x[j+tau])^2
        var diff = [Float](repeating: 0, count: tauMax + 1)
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for tau in 1...tauMax {
                var d: Float = 0
                vDSP_distancesq(base, 1, base + tau, 1, &d, vDSP_Length(window))
                diff[tau] = d
            }
        }

        // 2. Cumulative mean normalised difference
        var cmnd = [Float](repeating: 1, count: tauMax + 1)
        var running: Float = 0
        for tau in 1...tauMax {
            running += diff[tau]
            cmnd[tau] = running > 0 ? diff[tau] * Float(tau) / running : 1
        }

        // 3. First dip under the threshold, walked down to its local minimum.
        //    This (not the loudest harmonic) is what keeps us on the true fundamental.
        var tauEstimate = -1
        var tau = tauMin
        while tau < tauMax {
            if cmnd[tau] < threshold {
                while tau + 1 < tauMax && cmnd[tau + 1] < cmnd[tau] { tau += 1 }
                tauEstimate = tau
                break
            }
            tau += 1
        }
        guard tauEstimate > 0 else { return nil }

        // 4. Parabolic interpolation for sub-sample accuracy.
        var better = Float(tauEstimate)
        let x0 = tauEstimate - 1
        let x2 = tauEstimate + 1
        if x0 >= 1 && x2 <= tauMax {
            let s0 = cmnd[x0], s1 = cmnd[tauEstimate], s2 = cmnd[x2]
            let denom = 2 * (2 * s1 - s2 - s0)
            if denom != 0 { better += (s2 - s0) / denom }
        }
        guard better > 0 else { return nil }
        return PitchEstimate(frequency: sampleRate / Double(better),
                             clarity: Double(max(0, 1 - cmnd[tauEstimate])))
    }
}
