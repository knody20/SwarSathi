import SwiftUI

struct GuruMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

enum GuruKnowledge {
    static let starters = ["What is Swara?", "What is Alankar?", "What is Raaga?", "What is Thaat?"]

    private static let entries: [(keys: [String], answer: String)] = [
        (["swara", "swar", "svara"], "Swaras are the notes of Indian classical music: Sa, Re, Ga, Ma, Pa, Dha, Ni. Sa and Pa are fixed (achal). Re, Ga, Dha and Ni also have a lower, komal form, and Ma has a higher, tivra form, giving twelve notes in an octave."),
        (["alankar", "alankaar"], "An alankar is a fixed pattern of swaras sung going up and down the scale, such as Sa Re Ga Re Sa. Practising alankars builds pitch control, breath, and speed, and it’s the foundation of daily riyaaz."),
        (["raag", "raaga", "raga"], "A raaga is a melodic framework: a set of swaras with rules for how they rise (aaroh) and fall (avaroh), characteristic phrases (pakad), and a mood often tied to a time of day. The same notes can sound completely different in different raagas."),
        (["thaat", "that"], "A thaat is a parent scale of seven swaras used to group raagas. In the Bhatkhande system there are ten: Bilawal, Khamaj, Kafi, Asavari, Bhairavi, Bhairav, Kalyan, Marwa, Poorvi and Todi."),
        (["sa ", "shadja", "tonic", "scale"], "Sa (Shadja) is the home note. You choose it to suit your voice, and every other swar is measured from it. That’s why SwarSathi first finds your comfortable Sa."),
        (["tanpura", "tambura"], "The tanpura is a drone instrument that sustains Sa and Pa. It gives the singer a steady reference, so your ear can judge whether each swar sits in tune."),
        (["taal", "tala", "tabla", "teental", "teentaal"], "A taal is a repeating rhythmic cycle counted in matras (beats). Teentaal has 16 beats in four groups of four. The first beat is the sam, the emphasised point where phrases usually resolve."),
        (["riyaaz", "riyaz", "practice", "practise"], "Riyaaz is daily, disciplined practice. Short, regular sessions with a tanpura, slow tempo and careful listening help more than long, occasional ones."),
        (["komal", "tivra", "shuddh"], "Shuddh means natural, komal means flat (a semitone lower), and tivra means sharp. Only Ma has a tivra form; Re, Ga, Dha and Ni have komal forms."),
    ]

    static func answer(for question: String) -> String {
        let q = " " + question.lowercased() + " "
        for entry in entries where entry.keys.contains(where: { q.contains($0) }) { return entry.answer }
        return "I don’t have an answer for that yet. Try asking about swara, alankar, raaga, thaat, taal, tanpura or riyaaz."
    }
}

struct SangeetGuruView: View {
    @State private var messages: [GuruMessage] = []
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenHeader(title: "Sangeet Guru", subtitle: "Ask question about music.").padding(.top, 8)
                        if messages.isEmpty { intro } else { conversation }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal, Theme.screenPadding)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo("end") } }
            }
            inputBar
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "book").foregroundStyle(Theme.maroon)
                Text("A little curiosity. A deeper practice.").font(.headline).foregroundStyle(Theme.ink)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sandDeep.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("START WITH A QUESTION").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                ForEach(Array(GuruKnowledge.starters.enumerated()), id: \.offset) { i, q in
                    Button { ask(q) } label: {
                        HStack { Text(q).font(.subheadline).foregroundStyle(Theme.ink); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted) }
                            .padding(.vertical, 14).padding(.horizontal, 14)
                    }
                    if i < GuruKnowledge.starters.count - 1 { Divider().overlay(Theme.gold.opacity(0.5)).padding(.horizontal, 12) }
                }
            }
            .background(Theme.sandSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var conversation: some View {
        VStack(spacing: 10) {
            ForEach(messages) { m in
                HStack {
                    if m.isUser { Spacer(minLength: 40) }
                    Text(m.text).font(.subheadline)
                        .foregroundStyle(m.isUser ? Color.white : Theme.ink)
                        .padding(12)
                        .background(m.isUser ? Theme.maroon : Theme.sandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if !m.isUser { Spacer(minLength: 40) }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("What is a Raaga?", text: $input).focused($focused).submitLabel(.send).onSubmit { ask(input) }
            Button { ask(input) } label: {
                Image(systemName: "paperplane.fill").font(.footnote).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(Theme.maroon, in: Circle())
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.leading, 16).padding(.trailing, 6).frame(height: 46)
        .background(Theme.sandDeep.opacity(0.55), in: Capsule())
        .padding(.horizontal, Theme.screenPadding).padding(.vertical, 8)
    }

    private func ask(_ question: String) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        input = ""
        withAnimation(.smooth) {
            messages.append(GuruMessage(text: q, isUser: true))
            messages.append(GuruMessage(text: GuruKnowledge.answer(for: q), isUser: false))
        }
    }
}
