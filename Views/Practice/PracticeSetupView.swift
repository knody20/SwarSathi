import SwiftUI

struct PracticeSetupView: View {
    @Environment(ProgressStore.self) private var store
    let alankar: Alankar
    @Binding var path: [PracticeRoute]

    @State private var tempo = 60
    @State private var repetitions = 3
    @State private var tanpuraOn = false
    @State private var tablaOn = false
    @State private var taal: Taal = .teentaal
    @State private var waitForNote = true
    @State private var tablaVolume = 0.6
    @State private var showTabla = false
    private let audio = AudioEngineManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Practice Setup")
                VStack(alignment: .leading, spacing: 2) {
                    Text(alankar.name).font(.headline)
                    Text(alankar.sequenceText).font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 12) {
                    StepperRow(title: "Tempo", value: "\(tempo) BPM", onMinus: { tempo = max(30, tempo - 5) }, onPlus: { tempo = min(180, tempo + 5) })
                    StepperRow(title: "Repetitions", value: "\(repetitions)", onMinus: { repetitions = max(1, repetitions - 1) }, onPlus: { repetitions = min(10, repetitions + 1) })
                    Toggle(isOn: $waitForNote) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wait for me").font(.subheadline)
                            Text("Move on only after you sing each note").font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.maroon)
                }
                .padding(14).cardStyle()

                instrumentRow(symbol: "music.note", title: "Tanpura", subtitle: "A steady foundation in Sa (\(store.saScale.noteName))", playing: tanpuraOn) {
                    tanpuraOn.toggle()
                    toggleTanpura()
                }
                instrumentRow(symbol: "cylinder.split.1x2", title: "Tabla", subtitle: "Rhythm for your riyaaz", playing: tablaOn) { showTabla = true }

                if (tanpuraOn || tablaOn) && !audio.isHeadphonesConnected {
                    Label("Use headphones with Tanpura or Tabla so the microphone only hears your voice.", systemImage: "headphones")
                        .font(.caption).foregroundStyle(Theme.warning)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .safeAreaInset(edge: .bottom) {
            Button { startPractice() } label: { Label("Start Practice", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.screenPadding).padding(.bottom, 8).background(Theme.background)
        }
        .swarScreen()
        .sheet(isPresented: $showTabla) {
            TablaSheet(taal: $taal, tempo: $tempo, isPlaying: $tablaOn, volume: $tablaVolume, onChange: applyTabla)
                .presentationDetents([.fraction(0.8), .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { audio.stopAll() }
    }

    private func instrumentRow(symbol: String, title: String, subtitle: String, playing: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                CircleIcon(symbol: playing ? "stop.fill" : "play.fill", filled: playing, size: 28)
            }
            .padding(12).cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(playing ? "on" : "off")")
    }

    private func toggleTanpura() {
        do {
            if tanpuraOn { try audio.startOutput() }
            audio.synth.setTanpura(tanpuraOn, saFrequency: store.saScale.frequency)
        } catch { tanpuraOn = false }
    }

    private func applyTabla() {
        do {
            if tablaOn { try audio.startOutput() }
            audio.synth.setTablaVolume(tablaVolume)
            audio.synth.setTabla(tablaOn, taal: taal, bpm: Double(tempo))
        } catch { tablaOn = false }
    }

    private func startPractice() {
        audio.stopAll()
        let plan = SessionPlan(alankar: alankar, tempoBPM: tempo, repetitions: repetitions,
                               tanpuraOn: tanpuraOn, tablaOn: tablaOn, taal: taal, waitForNote: waitForNote)
        path.append(.live(plan))
    }
}

struct StepperRow: View {
    let title: String, value: String
    let onMinus: () -> Void, onPlus: () -> Void
    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            HStack(spacing: 14) {
                Button(action: onMinus) { Image(systemName: "minus") }.accessibilityLabel("Decrease \(title)")
                Text(value).font(.footnote.weight(.semibold)).frame(minWidth: 62).contentTransition(.numericText())
                Button(action: onPlus) { Image(systemName: "plus") }.accessibilityLabel("Increase \(title)")
            }
            .foregroundStyle(Theme.maroon)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Theme.sandSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.snappy, value: value)
        }
    }
}

struct TablaSheet: View {
    @Binding var taal: Taal
    @Binding var tempo: Int
    @Binding var isPlaying: Bool
    @Binding var volume: Double
    let onChange: () -> Void

    private var tempoName: String { tempo <= 60 ? "Vilambit" : (tempo <= 100 ? "Madhya" : "Drut") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tabla").font(.title2.weight(.bold))
                        Text("Keep the rhythm and practise your alankars with a steady beat.").font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Group {
                        if UIImage(named: "tabla") != nil { Image("tabla").resizable().scaledToFill() }
                        else { Theme.sandSoft.overlay(Image(systemName: "cylinder.split.1x2").font(.title).foregroundStyle(Theme.maroon)) }
                    }
                    .frame(width: 96, height: 72).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("Choose a Taal").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(Taal.allCases) { t in
                        Button { taal = t; onChange() } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "circle.grid.2x2").font(.footnote)
                                Text(t.name).font(.caption2.weight(.bold))
                                Text("(\(t.matras))").font(.caption2).foregroundStyle(Theme.muted)
                            }
                            .foregroundStyle(Theme.ink).frame(maxWidth: .infinity, minHeight: 64)
                            .background(Theme.sandSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(taal == t ? Theme.maroon : Theme.cardStroke, lineWidth: taal == t ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(taal == t ? .isSelected : [])
                    }
                }

                Text("Tempo").font(.subheadline.weight(.semibold))
                HStack {
                    Button { tempo = max(30, tempo - 5); onChange() } label: { Image(systemName: "minus").frame(width: 40, height: 40).background(Theme.sand, in: Circle()) }
                        .accessibilityLabel("Slower")
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(tempo) BPM").font(.title.weight(.bold)).contentTransition(.numericText())
                        Text(tempoName).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { tempo = min(180, tempo + 5); onChange() } label: { Image(systemName: "plus").frame(width: 40, height: 40).background(Theme.sand, in: Circle()) }
                        .accessibilityLabel("Faster")
                }
                .foregroundStyle(Theme.maroon)
                .animation(.snappy, value: tempo)

                Button { isPlaying.toggle(); onChange() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.title2).foregroundStyle(.white)
                        .frame(width: 72, height: 72).background(Theme.maroon, in: Circle())
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(isPlaying ? "Stop tabla" : "Play tabla")

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").foregroundStyle(Theme.muted)
                    Slider(value: $volume, in: 0...1) { _ in onChange() }.tint(Theme.maroon)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(Theme.muted)
                }
                Text("This is a synthesised taal beat for timing. Recorded tabla samples are planned.").font(.caption2).foregroundStyle(Theme.muted)
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.background)
    }
}

struct OpenRiyazView: View {
    @State private var listener: LivePitchListener

    init(sa: SaScale, settings: PracticeSettings) {
        _listener = State(initialValue: LivePitchListener(sa: sa, settings: settings, target: nil))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(title: "Open Riyaz", subtitle: "Sing freely. We’ll show the swar you’re on.")
            VStack(spacing: 14) {
                Text(listener.detectedSwar?.label ?? "–").font(.system(size: 72, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.maroon).contentTransition(.interpolate)
                    .animation(.snappy, value: listener.detectedSwar)
                PitchMeter(cents: listener.cents)
                HStack { Text("Flat").font(.caption2); Spacer(); Text("On note").font(.caption2); Spacer(); Text("Sharp").font(.caption2) }
                    .foregroundStyle(Theme.muted)
                StatusPill(feedback: listener.feedback)
                LevelBars(level: listener.level)
            }
            .padding(20).frame(maxWidth: .infinity).cardStyle()
            Toggle(isOn: Binding(get: { listener.tanpuraOn }, set: { listener.setTanpura($0) })) {
                Label("Tanpura in Sa (\(listener.sa.noteName))", systemImage: "music.note")
            }
            .tint(Theme.maroon).padding(14).cardStyle()
            if listener.micDenied { MicDeniedNotice() }
            Spacer()
        }
        .padding(.horizontal, Theme.screenPadding)
        .swarScreen()
        .task { await listener.start() }
        .onDisappear { listener.stop() }
    }
}
