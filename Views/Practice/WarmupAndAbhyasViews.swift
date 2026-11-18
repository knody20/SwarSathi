import SwiftUI

struct WarmupListView: View {
    @Binding var path: [PracticeRoute]

    private struct Item: Identifiable {
        let id: String, symbol: String, title: String, subtitle: String, route: PracticeRoute?
    }
    private let items: [Item] = [
        Item(id: "abhyas", symbol: "music.note", title: "Swar Abhyas", subtitle: "Listen to notes and practise", route: .swarAbhyas),
        Item(id: "hum", symbol: "waveform", title: "Vocal Humming", subtitle: "Hum gently to warm up your voice", route: nil),
        Item(id: "range", symbol: "arrow.up.and.down", title: "Explore your range", subtitle: "Find how high and low you can sing", route: nil),
        Item(id: "breath", symbol: "wind", title: "Mindful Breathing", subtitle: "Practise breathing slowly and steadily", route: nil),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Warmup Exercises", subtitle: "Choose an exercise to start.").padding(.bottom, 4)
                ForEach(items) { item in
                    Button { if let route = item.route { path.append(route) } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).foregroundStyle(Theme.maroon).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text(item.subtitle).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if item.route == nil {
                                Text("Soon").font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Theme.sandSoft, in: Capsule())
                            } else {
                                CircleIcon(symbol: "play.fill", size: 26)
                            }
                        }
                        .padding(14).cardStyle()
                    }
                    .buttonStyle(.plain)
                    .disabled(item.route == nil)
                    .opacity(item.route == nil ? 0.65 : 1)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .swarScreen()
    }
}

struct SwarAbhyasView: View {
    @State private var listener: LivePitchListener
    @Environment(\.dismiss) private var dismiss

    init(sa: SaScale, settings: PracticeSettings) {
        _listener = State(initialValue: LivePitchListener(sa: sa, settings: settings, target: .ga))
    }

    private var rows: [ChartRow] { Swar.natural.map { ChartRow(label: $0.label, semitone: Double($0.semitone)) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Swar Abhyas", subtitle: "Select and master each Swara.")

            FlowLayout(spacing: 8) {
                ForEach(Swar.natural) { swar in
                    Button { listener.select(swar) } label: {
                        Text(swar.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.maroon)
                            .frame(width: 52, height: 36)
                            .background(listener.target == swar ? Theme.sandDeep : Theme.sand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityLabel("\(swar.name)\(listener.target == swar ? ", selected" : "")")
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle()

            VStack(spacing: 10) {
                HStack { LevelBars(level: listener.level); Spacer() }
                PitchChart(samples: listener.chart, rows: rows, now: listener.clock,
                           activeSemitone: listener.target.map { Double($0.semitone) })
                    .frame(height: 220)
            }
            .padding(14).cardStyle()

            HStack {
                Text("Hold a steady \(listener.target?.label ?? "Sa").").font(.footnote).foregroundStyle(Theme.muted)
                Spacer()
                StatusPill(feedback: listener.feedback)
            }

            if listener.micDenied { MicDeniedNotice() }
            Spacer()
            Button("End Session") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 12)
        .swarScreen()
        .task { await listener.start() }
        .onDisappear { listener.stop() }
    }
}

struct MicDeniedNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Microphone access is off", systemImage: "mic.slash.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.danger)
            Text("SwarSathi needs the microphone to hear your pitch. Turn it on in Settings.").font(.caption).foregroundStyle(Theme.muted)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.font(.caption.weight(.semibold))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle(fill: Theme.dangerSoft)
    }
}
