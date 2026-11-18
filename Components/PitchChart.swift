import SwiftUI

struct ChartSample {
    let time: Double
    /// Semitones above Sa; nil while silent.
    let voice: Double?
    let target: Double
}

struct ChartRow: Identifiable {
    let label: String
    let semitone: Double
    var id: String { label }
}

/// Scrolling "target vs your voice" chart: dashed stepped line = target, solid line = your voice.
struct PitchChart: View {
    let samples: [ChartSample]
    let rows: [ChartRow]
    let now: Double
    var activeSemitone: Double?
    var window: Double = 8
    var playheadFraction: Double = 0.82

    var body: some View {
        Canvas { context, size in
            guard let lo = rows.map(\.semitone).min(), let hi = rows.map(\.semitone).max() else { return }
            let left: CGFloat = 34
            let plot = CGRect(x: left, y: 6, width: size.width - left - 4, height: size.height - 12)
            let span = max(hi - lo, 1)
            func y(_ s: Double) -> CGFloat { plot.maxY - plot.height * CGFloat(0.06 + 0.88 * (s - lo) / span) }
            func x(_ t: Double) -> CGFloat { plot.minX + CGFloat(playheadFraction + (t - now) / window) * plot.width }

            for row in rows {
                var line = Path()
                let yy = y(row.semitone)
                line.move(to: CGPoint(x: plot.minX, y: yy))
                line.addLine(to: CGPoint(x: plot.maxX, y: yy))
                context.stroke(line, with: .color(Theme.cardStroke), lineWidth: 0.7)
                let active = activeSemitone == row.semitone
                context.draw(Text(row.label).font(.caption2.weight(active ? .bold : .regular)).foregroundStyle(active ? Theme.maroon : Theme.muted),
                             at: CGPoint(x: 2, y: yy), anchor: .leading)
            }

            // Playhead
            let headX = x(now)
            context.fill(Path(CGRect(x: headX - 4, y: plot.minY, width: 8, height: plot.height)), with: .color(Theme.sand.opacity(0.55)))

            let visible = samples.filter { x($0.time) >= plot.minX }

            var target = Path()
            var lastTarget: Double?
            for s in visible {
                let p = CGPoint(x: x(s.time), y: y(s.target))
                if let last = lastTarget {
                    if last != s.target { target.addLine(to: CGPoint(x: p.x, y: y(last))) }
                    target.addLine(to: p)
                } else {
                    target.move(to: p)
                }
                lastTarget = s.target
            }
            context.stroke(target, with: .color(Theme.warning), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))

            var voice = Path()
            var penDown = false
            var lastPoint: CGPoint?
            for s in visible {
                guard let v = s.voice else { penDown = false; continue }
                let p = CGPoint(x: x(s.time), y: min(max(y(v), plot.minY), plot.maxY))
                if penDown { voice.addLine(to: p) } else { voice.move(to: p); penDown = true }
                lastPoint = p
            }
            context.stroke(voice, with: .color(Theme.maroon), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            if let p = lastPoint, let last = samples.last, last.voice != nil {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(Theme.maroon))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Live pitch comparison chart")
    }
}

/// Five bars that breathe with microphone level.
struct LevelBars: View {
    let level: Double
    private let weights: [Double] = [0.5, 0.85, 1, 0.75, 0.45]
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<5, id: \.self) { i in
                Capsule().fill(Theme.maroon)
                    .frame(width: 3, height: 5 + 13 * level * weights[i])
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }
}

/// Horizontal cents meter used in Open Riyaz: centre = on the note.
struct PitchMeter: View {
    let cents: Double?
    let range: Double = 50
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Capsule().fill(Theme.sandSoft)
                Capsule().fill(Theme.successSoft).frame(width: geo.size.width * 0.2)
                Rectangle().fill(Theme.gold).frame(width: 2)
                if let cents {
                    let clamped = max(-range, min(range, cents))
                    Circle().fill(Theme.maroon).frame(width: 18, height: 18)
                        .offset(x: CGFloat(clamped / range) * (geo.size.width / 2 - 9))
                        .animation(.smooth(duration: 0.12), value: clamped)
                }
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}
