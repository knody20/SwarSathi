import SwiftUI

struct AlankarListView: View {
    @Environment(ProgressStore.self) private var store
    @Binding var path: [PracticeRoute]
    @State private var customized = false
    @State private var query = ""

    private var items: [Alankar] {
        let base = customized ? store.customAlankars : Alankar.presets
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.sequenceText.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(title: "Alankar Practice")
            segmented
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Search", text: $query).textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(Theme.sandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            ScrollView {
                LazyVStack(spacing: 10) {
                    if items.isEmpty {
                        Text(customized ? "You haven’t created any alankars yet." : "No alankars match your search.")
                            .font(.footnote).foregroundStyle(Theme.muted).padding(.top, 40)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, alankar in
                        Button { path.append(.setup(alankar)) } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.maroon)
                                    .frame(width: 34, height: 34).background(Theme.sand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alankar.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Text(alankar.sequenceText).font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                CircleIcon(symbol: "play.fill", size: 26)
                            }
                            .padding(12).cardStyle()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if alankar.isCustom {
                                Button("Delete", systemImage: "trash", role: .destructive) { store.deleteAlankar(alankar) }
                            }
                        }
                    }
                }
            }
            if customized {
                Button { path.append(.buildAlankar) } label: { Label("Create New Alankar", systemImage: "plus.circle") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, Theme.screenPadding).padding(.bottom, 12)
        .swarScreen()
        .animation(.smooth, value: customized)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { isCustom in
                Button { customized = isCustom } label: {
                    Text(isCustom ? "Customized" : "Presets").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background { if customized == isCustom { Capsule().fill(Theme.sand) } }
                }
                .accessibilityAddTraits(customized == isCustom ? .isSelected : [])
            }
        }
        .padding(3).background(Theme.sandSoft.opacity(0.7), in: Capsule())
        .frame(maxWidth: 260).frame(maxWidth: .infinity)
    }
}

struct BuildAlankarView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var sequence: [Swar] = []
    private let maxNotes = 16
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Build Your Alankar", subtitle: "Tap the swaras to create your sequence.")
                HStack {
                    Text("Your Sequence").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(sequence.count) notes").font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(.top, 6)

                FlowLayout(spacing: 6) {
                    if sequence.isEmpty { Text("Your notes will appear here").font(.footnote).foregroundStyle(Theme.muted) }
                    ForEach(Array(sequence.enumerated()), id: \.offset) { index, swar in
                        HStack(spacing: 4) {
                            Text(swar.label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.maroon)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.sand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            if index < sequence.count - 1 { Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Theme.muted) }
                        }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).cardStyle()

                HStack(spacing: 10) {
                    Button { if !sequence.isEmpty { sequence.removeLast() } } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(OutlineButtonStyle()).disabled(sequence.isEmpty)
                    Button { sequence.removeAll() } label: { Label("Clear All", systemImage: "trash") }
                        .buttonStyle(OutlineButtonStyle()).disabled(sequence.isEmpty)
                    Spacer()
                }
                .frame(maxWidth: 260, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Swar.builderOrder) { swar in
                        Button { add(swar) } label: {
                            VStack(spacing: 2) {
                                Text(swar.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.maroon)
                                Text(swar.variant).font(.system(size: 9)).foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48).cardStyle(radius: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(swar.spokenLabel)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save Alankar") { store.saveAlankar(swars: sequence); dismiss() }
                .buttonStyle(PrimaryButtonStyle()).disabled(sequence.count < 2)
                .padding(.horizontal, Theme.screenPadding).padding(.bottom, 8)
                .background(Theme.background)
        }
        .swarScreen()
        .sensoryFeedback(.selection, trigger: sequence.count)
    }

    private func add(_ swar: Swar) {
        guard sequence.count < maxNotes else { return }
        withAnimation(.snappy) { sequence.append(swar) }
    }
}
