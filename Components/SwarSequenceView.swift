import SwiftUI

/// Horizontal sequence of swars: completed / current / upcoming, auto-centred on the current note.
struct SwarSequenceView: View {
    let swars: [Swar]
    let progress: [NoteProgress]
    let currentIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(swars.indices, id: \.self) { i in
                        chip(i).id(i)
                    }
                }
                .padding(.horizontal, Theme.screenPadding).padding(.vertical, 8)
            }
            .onChange(of: currentIndex) { _, new in
                withAnimation(.smooth) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func chip(_ i: Int) -> some View {
        let state = progress.indices.contains(i) ? progress[i] : .upcoming
        return ZStack(alignment: .topTrailing) {
            Text(swars[i].label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state == .current ? Color.white : (state == .upcoming ? Theme.ink : Theme.maroon))
                .frame(width: 56, height: 44)
                .background(fill(state), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(state == .upcoming ? Theme.cardStroke : Color.clear, lineWidth: 1))
            if state == .clean || state == .needsWork {
                Image(systemName: state == .clean ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption).foregroundStyle(state == .clean ? Theme.success : Theme.warning)
                    .background(Circle().fill(Theme.card)).offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(state == .current ? 1.1 : 1)
        .shadow(color: state == .current ? Theme.maroon.opacity(0.3) : .clear, radius: 8, y: 3)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(swars[i].spokenLabel), \(label(state))")
    }

    private func fill(_ s: NoteProgress) -> Color {
        switch s {
        case .current: return Theme.maroon
        case .clean: return Theme.sand
        case .needsWork: return Theme.warningSoft
        case .upcoming: return Theme.card
        }
    }
    private func label(_ s: NoteProgress) -> String {
        switch s {
        case .current: return "current note"
        case .clean: return "sung well"
        case .needsWork: return "needs more practice"
        case .upcoming: return "upcoming"
        }
    }
}
