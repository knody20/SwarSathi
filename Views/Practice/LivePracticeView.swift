import SwiftUI

/// Figma "Alankar 2" live screen: sequence chips, live pitch comparison chart, status, pause / finish.
struct LivePracticeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var vm: PracticeViewModel
    @Binding var path: [PracticeRoute]
    private let plan: SessionPlan

    init(plan: SessionPlan, sa: SaScale, settings: PracticeSettings, path: Binding<[PracticeRoute]>) {
        self.plan = plan
        _path = path
        _vm = State(initialValue: PracticeViewModel(plan: plan, sa: sa, settings: settings))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            SwarSequenceView(swars: vm.swars, progress: vm.progress, currentIndex: vm.currentIndex)
                .padding(.horizontal, -Theme.screenPadding)

            Text(vm.message ?? "Sing this sequence")
                .font(.footnote.weight(vm.message == nil ? .regular : .semibold))
                .foregroundStyle(vm.message == nil ? Theme.muted : Theme.maroon)
                .frame(maxWidth: .infinity)
                .animation(.smooth, value: vm.message)

            chartCard

            HStack {
                Button { vm.playAlong.toggle(); if vm.playAlong { vm.replayReference() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.playAlong ? "speaker.wave.2.circle.fill" : "play.circle")
                        Text("Play along")
                    }
                    .font(.footnote).foregroundStyle(Theme.maroon)
                }
                .accessibilityValue(vm.playAlong ? "On" : "Off")
                Spacer()
                StatusPill(feedback: vm.feedback)
            }

            if let cents = vm.cents, !vm.feedback.isOnPitch {
                Text(String(format: "%@%.0f cents from %@", cents > 0 ? "+" : "−", abs(cents), vm.currentSwar.label))
                    .font(.caption2).foregroundStyle(Theme.muted)
            }
            if vm.showHeadphoneHint {
                Label("Use headphones so Tanpura/Tabla aren’t picked up by the mic.", systemImage: "headphones")
                    .font(.caption).foregroundStyle(Theme.warning)
            }
            if vm.micDenied { MicDeniedNotice() }
            if let error = vm.errorMessage { Text(error).font(.caption).foregroundStyle(Theme.danger) }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button { vm.togglePause() } label: { Label(vm.isPaused ? "Resume" : "Pause", systemImage: vm.isPaused ? "play.fill" : "pause.fill") }
                    .buttonStyle(OutlineButtonStyle())
                Button { vm.finish() } label: { Label("Finish", systemImage: "stop.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, Theme.screenPadding).padding(.bottom, 12)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BackButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Replay reference note", systemImage: "speaker.wave.2") { vm.replayReference() }
                    Button("Skip note", systemImage: "forward.end") { vm.skipNote() }
                    Button("Restart", systemImage: "arrow.counterclockwise") { vm.restart() }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Theme.maroon) }
                .accessibilityLabel("More options")
            }
        }
        .task {
            vm.onFinished = { [store] session in
                guard let session else { path.removeLast(); return }
                store.add(session)
                path.removeLast()
                path.append(.report(session, plan))
            }
            await vm.start()
        }
        .onDisappear { vm.teardown() }
        .sensoryFeedback(.success, trigger: vm.cleanTick)
        .sensoryFeedback(.warning, trigger: vm.missTick)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.alankar.name).font(.screenTitle).foregroundStyle(Theme.maroon)
            HStack(spacing: 8) {
                Text("\(plan.alankar.difficulty.rawValue) · Round \(vm.repetition) of \(plan.repetitions)")
                Spacer()
                Text(Duration.seconds(vm.clock).formatted(.time(pattern: .minuteSecond))).monospacedDigit()
            }
            .font(.caption).foregroundStyle(Theme.muted)
            ProgressView(value: vm.sessionFraction).tint(Theme.maroon)
                .animation(.smooth, value: vm.sessionFraction)
                .accessibilityLabel("Session progress")
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LevelBars(level: vm.level)
                Text("Live Pitch Comparison").font(.footnote.weight(.semibold)).foregroundStyle(Theme.maroon)
                Spacer()
            }
            PitchChart(samples: vm.chart, rows: vm.rows, now: vm.clock, activeSemitone: Double(vm.currentSwar.semitone))
                .frame(height: 200)
            HStack(spacing: 16) {
                legend(dashed: true, text: "Target pitch")
                legend(dashed: false, text: "Your voice")
            }
            .font(.caption2).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
        }
        .padding(14).cardStyle()
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .stroke(Theme.success.opacity(vm.feedback.isOnPitch ? 0.8 : 0), lineWidth: 2))
        .shadow(color: Theme.success.opacity(vm.feedback.isOnPitch ? 0.25 : 0), radius: 10)
        .animation(.easeOut(duration: 0.2), value: vm.feedback.isOnPitch)
        .opacity(vm.isPaused ? 0.5 : 1)
    }

    private func legend(dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(dashed ? Theme.warning : Theme.maroon).frame(width: 18, height: dashed ? 1.5 : 2.4)
                .mask(HStack(spacing: dashed ? 3 : 0) { ForEach(0..<(dashed ? 4 : 1), id: \.self) { _ in Rectangle() } })
            Text(text)
        }
    }
}
