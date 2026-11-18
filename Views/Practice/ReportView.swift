import Charts
import SwiftUI

struct ReportView: View {
    @Environment(ProgressStore.self) private var store
    let session: PracticeSession
    let plan: SessionPlan
    @Binding var path: [PracticeRoute]
    @State private var shown = 0.0
    @State private var showDetails = false

    private var previous: PracticeSession? {
        store.sessions(for: session.alankarID).last { $0.id != session.id && $0.date < session.date }
    }
    private var best: Double? {
        store.sessions(for: session.alankarID).filter { $0.id != session.id }.map(\.accuracy).max()
    }
    private var headline: String {
        if let best, session.accuracy > best { return "A new personal best!" }
        if let previous, session.accuracy > previous.accuracy { return "Your pitch accuracy is improving." }
        if session.accuracy >= 0.9 { return "Beautifully sung!" }
        if session.accuracy >= 0.6 { return "One more repetition to master this Alankar!" }
        return "Every round makes your ear sharper."
    }

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "Practice Report", subtitle: "\(session.alankarName) · Session Summary")

            VStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Theme.sand, lineWidth: 12)
                    Circle().trim(from: 0, to: shown).stroke(Theme.maroon, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int((shown * 100).rounded()))%").font(.system(size: 44, weight: .bold)).contentTransition(.numericText())
                        Text("pitch accuracy").font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 170, height: 170).padding(.top, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pitch accuracy \(Int(session.accuracy * 100)) percent")

                Divider()
                HStack {
                    stat("\(session.notesOnPitch) / \(session.totalNotes)", "Notes on pitch")
                    Divider().frame(height: 34)
                    stat(Duration.seconds(session.duration).formatted(.time(pattern: .minuteSecond)), "Minutes practiced")
                }
            }
            .padding(18).cardStyle(radius: 20)

            Text(headline).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.maroon).multilineTextAlignment(.center)
            if let previous {
                let delta = Int((session.accuracy - previous.accuracy) * 100)
                Text(delta == 0 ? "Same as your last attempt." : "\(delta > 0 ? "Up" : "Down") \(abs(delta))% from your last attempt.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            Button("View Detailed Analysis") { showDetails = true }.font(.footnote.weight(.semibold))
            Spacer()

            VStack(spacing: 10) {
                Button("Practice Again") { path.removeLast(); path.append(.live(plan)) }.buttonStyle(SecondaryButtonStyle())
                Button("Try Next Alankar") { path.removeLast(); path.append(.setup(store.nextAlankar(after: plan.alankar))) }
                    .font(.footnote.weight(.semibold))
                Button("Finish") { path.removeAll() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, Theme.screenPadding).padding(.bottom, 12)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .sensoryFeedback(.success, trigger: shown >= session.accuracy)
        .sheet(isPresented: $showDetails) { DetailSheet(session: session, history: store.sessions(for: session.alankarID)) }
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { shown = session.accuracy } }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailSheet: View {
    let session: PracticeSession
    let history: [PracticeSession]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if history.count > 1 {
                        Text("Accuracy over your attempts").font(.subheadline.weight(.semibold))
                        Chart(Array(history.suffix(8).enumerated()), id: \.element.id) { index, s in
                            BarMark(x: .value("Attempt", index + 1), y: .value("Accuracy", s.accuracy * 100))
                                .foregroundStyle(s.id == session.id ? Theme.maroon : Theme.sandDeep)
                        }
                        .chartYScale(domain: 0...100).frame(height: 140)
                    }
                    Text("Note by note").font(.subheadline.weight(.semibold))
                    ForEach(session.results) { r in
                        HStack {
                            Image(systemName: r.passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(r.passed ? Theme.success : Theme.warning)
                            Text(r.swar.label).font(.subheadline.weight(.semibold))
                            Spacer()
                            if let dev = r.averageDeviationCents { Text("avg \(Int(dev.rounded()))¢ off").font(.caption).foregroundStyle(Theme.muted) }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(r.swar.spokenLabel), \(r.passed ? "on pitch" : "needs improvement")")
                    }
                    if !session.weakSwars.isEmpty {
                        Text("Needs improvement: \(session.weakSwars.map(\.label).joined(separator: ", "))")
                            .font(.footnote).foregroundStyle(Theme.warning)
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.background)
            .navigationTitle("Detailed Analysis").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
