import SwiftUI

enum PracticeRoute: Hashable {
    case warmups, swarAbhyas, alankarList, buildAlankar, openRiyaz
    case setup(Alankar)
    case live(SessionPlan)
    case report(PracticeSession, SessionPlan)
}

struct PracticeTab: View {
    @Binding var path: [PracticeRoute]
    @Environment(ProgressStore.self) private var store

    var body: some View {
        NavigationStack(path: $path) {
            PracticeHomeView(path: $path)
                .navigationDestination(for: PracticeRoute.self) { route in destination(route) }
        }
    }

    @ViewBuilder private func destination(_ route: PracticeRoute) -> some View {
        switch route {
        case .warmups: WarmupListView(path: $path)
        case .swarAbhyas: SwarAbhyasView(sa: store.saScale, settings: store.settings)
        case .alankarList: AlankarListView(path: $path)
        case .buildAlankar: BuildAlankarView()
        case .openRiyaz: OpenRiyazView(sa: store.saScale, settings: store.settings)
        case .setup(let alankar): PracticeSetupView(alankar: alankar, path: $path)
        case .live(let plan): LivePracticeView(plan: plan, sa: store.saScale, settings: store.settings, path: $path)
        case .report(let session, let plan): ReportView(session: session, plan: plan, path: $path)
        }
    }
}

struct PracticeHomeView: View {
    @Environment(ProgressStore.self) private var store
    @Binding var path: [PracticeRoute]
    @State private var showProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Hi, \(store.profile.name)", subtitle: "What would you like to practice?")
                    Button { showProfile = true } label: { AvatarView(name: store.profile.name, size: 44) }
                        .accessibilityLabel("Profile")
                }
                .padding(.top, 8)

                ActionRow(symbol: "mic", title: "Warmup Exercise", subtitle: "Open up your vocal cords") { path.append(.warmups) }
                ActionRow(symbol: "music.note", title: "Focused Alankar Session", subtitle: "Practice your weak notes") {
                    path.append(.setup(store.focusedAlankar()))
                }

                HStack(spacing: 12) {
                    BigTile(symbol: "music.note", title: "Alankar\nPractice", subtitle: "Listen to alankar\nand practise", dark: true) { path.append(.alankarList) }
                    BigTile(symbol: "waveform", title: "Open\nRiyaz", subtitle: "Sing freely with\ninstruments", dark: false) { path.append(.openRiyaz) }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showProfile) { ProfileView() }
    }
}

struct ActionRow: View {
    let symbol: String, title: String, subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.maroon)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                CircleIcon(symbol: "play.fill", filled: true, size: 30)
            }
            .padding(14).cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct BigTile: View {
    let symbol: String, title: String, subtitle: String
    let dark: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).font(.title3).foregroundStyle(dark ? Color.white : Theme.maroon)
                Spacer(minLength: 16)
                Text(title).font(.headline).foregroundStyle(dark ? Color.white : Theme.maroon)
                Text(subtitle).font(.caption).foregroundStyle(dark ? Color.white.opacity(0.85) : Theme.maroon.opacity(0.85))
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .padding(16)
            .background(dark ? Theme.maroon : Theme.sandDeep, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
