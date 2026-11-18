import SwiftUI

/// Three sampling steps (lower, upper, normal Sa) then the result. Also reused for "Update your Scale".
struct OnboardingFlowView: View {
    let onComplete: (SaScale) -> Void
    let onCancel: (() -> Void)?

    @State private var vm = ScaleDetectionViewModel()
    @State private var showResult = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background.ignoresSafeArea()
            if showResult, let scale = vm.result {
                SaResultView(scale: scale) { onComplete(scale) }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                SampleStepView(vm: vm) {
                    withAnimation(.smooth) { showResult = vm.advance() }
                }
                .id(vm.step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            if let onCancel {
                Button { vm.stop(); onCancel() } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Theme.maroon).padding(16)
                }
                .accessibilityLabel("Close")
            }
        }
        .animation(.smooth, value: vm.step)
        .onDisappear { vm.stop() }
    }
}

struct SampleStepView: View {
    let vm: ScaleDetectionViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Find your Sa").font(.brandTitle).foregroundStyle(Theme.maroon)
                .accessibilityAddTraits(.isHeader)
            Text(vm.step.subtitle).font(.footnote).foregroundStyle(Theme.muted).padding(.top, 2)

            StepProgressBar(current: vm.step.rawValue, total: 3).padding(.top, 16)
                .accessibilityLabel("Step \(vm.step.rawValue + 1) of 3")

            Spacer()

            MicCaptureButton(state: vm.state, progress: vm.progress, level: vm.level, action: vm.toggleCapture)
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text(vm.step.instructionTitle).font(.headline).foregroundStyle(Theme.muted)
                Text(vm.step.instructionBody).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                feedbackLine.frame(minHeight: 40)
            }
            .frame(maxWidth: .infinity).padding(.top, 36)

            Spacer()

            HStack(spacing: 12) {
                Button("Retry", action: vm.retry).buttonStyle(SecondaryButtonStyle())
                Button("Next", action: onNext).buttonStyle(PrimaryButtonStyle()).disabled(!vm.isCaptured)
            }
        }
        .padding(Theme.screenPadding)
    }

    @ViewBuilder private var feedbackLine: some View {
        if vm.micDenied {
            VStack(spacing: 6) {
                Text("Microphone access is off. SwarSathi needs it to hear you sing.")
                    .font(.caption).foregroundStyle(Theme.danger).multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.font(.caption.weight(.semibold))
            }
        } else if vm.isListening {
            Label("Listening… hold the note steady", systemImage: "waveform").font(.caption.weight(.semibold)).foregroundStyle(Theme.maroon)
        } else if let note = vm.capturedNoteText {
            Label("Heard \(note)", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.success)
        } else if case .failed(let message) = vm.state {
            Text(message).font(.caption).foregroundStyle(Theme.danger).multilineTextAlignment(.center)
        } else {
            Text("Tap the microphone to begin").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

struct StepProgressBar: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i == current ? Theme.maroon : Theme.gold).frame(height: 3)
            }
        }
        .animation(.smooth, value: current)
    }
}

struct MicCaptureButton: View {
    let state: ScaleDetectionViewModel.CaptureState
    let progress: Double
    let level: Double
    let action: () -> Void

    private var listening: Bool { state == .listening }
    private var symbol: String {
        if listening { return "waveform" }
        if case .captured = state { return "checkmark" }
        return "mic"
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardStroke, lineWidth: 1).frame(width: 150, height: 150)
            Circle().fill(Theme.sand.opacity(0.45)).frame(width: 118, height: 118)
                .scaleEffect(listening ? 1 + level * 0.28 : 1)
                .animation(.easeOut(duration: 0.12), value: level)
            Circle().trim(from: 0, to: progress).stroke(Theme.maroon, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: 150, height: 150)
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Theme.maroon)
                    .symbolEffect(.variableColor.iterative, isActive: listening)
                    .frame(width: 80, height: 80)
                    .background(Theme.sand, in: Circle())
                    .overlay(Circle().stroke(Theme.maroon, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(listening ? "Stop listening" : "Start listening")
        }
        .frame(height: 160)
    }
}

struct SaResultView: View {
    let scale: SaScale
    let onBegin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Sa").font(.brandTitle).foregroundStyle(Theme.maroon)
            Text("Based on the note you sang.").font(.footnote).foregroundStyle(Theme.muted).padding(.top, 2)

            VStack(spacing: 8) {
                Text("YOUR COMFORTABLE SA").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Theme.muted)
                Text(scale.noteName).font(.system(size: 72, weight: .medium)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("≈ \(Int(scale.frequency.rounded())) Hz").font(.caption).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
            .background(Theme.sand, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 60)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your comfortable Sa is \(scale.noteName)")

            Spacer()
            Text("You can change your scale later.").font(.caption).foregroundStyle(Theme.muted).padding(.bottom, 12)
            Button("Let’s Begin", action: onBegin).buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.screenPadding)
    }
}
