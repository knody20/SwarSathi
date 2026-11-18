import SwiftUI

struct InsightsView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Insights", subtitle: "Your riyaaz journey at a glance.").padding(.top, 8)
                    HStack(spacing: 10) {
                        StatTile(symbol: "flame.fill", value: "\(store.currentStreak)", label: "Day Streak")
                        StatTile(symbol: "calendar", value: "\(store.sessions.count)", label: "Sessions")
                        StatTile(symbol: "scope", value: store.sessions.isEmpty ? "–" : "\(Int((store.averageAccuracy * 100).rounded()))%", label: "Avg. Accuracy")
                    }
                    recentCard
                    achievementsCard
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recently Done Sessions").font(.footnote.weight(.semibold)).foregroundStyle(Theme.maroon)
                Spacer()
                if !store.sessions.isEmpty {
                    NavigationLink { SessionHistoryView() } label: { Text("View Details ›").font(.caption.weight(.semibold)) }
                }
            }
            if let last = store.recentSessions.first {
                SessionRow(session: last)
            } else {
                Text("Complete an Alankar and it will show up here.").font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle()
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements").font(.footnote.weight(.semibold)).foregroundStyle(Theme.maroon)
            HStack {
                ForEach(store.achievements) { a in
                    VStack(spacing: 6) {
                        Image(systemName: a.unlocked ? a.symbol.replacingOccurrences(of: "lock.fill", with: "trophy.fill") : "lock.fill")
                            .font(.footnote).foregroundStyle(a.unlocked ? Color.white : Theme.muted)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(a.unlocked ? Theme.maroon : Theme.sandSoft))
                        Text(a.unlocked ? a.title : a.lockedTitle).font(.system(size: 10)).multilineTextAlignment(.center)
                            .foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(a.title), \(a.unlocked ? "unlocked" : "locked")")
                }
            }
        }
        .padding(14).cardStyle()
    }
}

struct StatTile: View {
    let symbol: String, value: String, label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.footnote).foregroundStyle(Theme.maroon)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).cardStyle()
        .accessibilityElement(children: .combine)
    }
}

struct SessionRow: View {
    let session: PracticeSession
    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "music.note", size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.alankarName).font(.subheadline.weight(.semibold))
                Text("\(max(1, Int((session.duration / 60).rounded()))) min · \(Int((session.accuracy * 100).rounded()))% Accuracy").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SessionHistoryView: View {
    @Environment(ProgressStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ScreenHeader(title: "Session History")
                ForEach(store.recentSessions) { SessionRow(session: $0).padding(12).cardStyle() }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .swarScreen()
    }
}
