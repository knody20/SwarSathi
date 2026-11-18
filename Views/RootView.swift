import SwiftUI

struct RootView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showWelcome = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if !store.profile.isSignedIn {
                if showWelcome {
                    WelcomeView().transition(.move(edge: .trailing))
                } else {
                    SplashView { withAnimation(.smooth) { showWelcome = true } }
                }
            } else if store.profile.saScale == nil {
                OnboardingFlowView(onComplete: { scale in
                    store.updateProfile { $0.saScale = scale }
                }, onCancel: nil)
                .transition(.opacity)
            } else {
                MainTabView().transition(.opacity)
            }
        }
        .animation(.smooth, value: store.profile.isSignedIn)
        .animation(.smooth, value: store.profile.saScale)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case insights, practice, guru
    var id: String { rawValue }
    var title: String {
        switch self {
        case .insights: return "Insights"
        case .practice: return "Practice"
        case .guru: return "Sangeet Guru"
        }
    }
    var symbol: String {
        switch self {
        case .insights: return "chart.bar.fill"
        case .practice: return "mic.fill"
        case .guru: return "book"
        }
    }
}

/// Native TabView (state preserved per tab) with the Figma's floating pill bar in place of the system bar.
struct MainTabView: View {
    @State private var tab: AppTab = .practice
    @State private var practicePath: [PracticeRoute] = []

    var body: some View {
        TabView(selection: $tab) {
            InsightsView().tag(AppTab.insights).toolbar(.hidden, for: .tabBar)
            PracticeTab(path: $practicePath).tag(AppTab.practice).toolbar(.hidden, for: .tabBar)
            SangeetGuruView().tag(AppTab.guru).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The Figma hides the bar on pushed Practice screens.
            if tab != .practice || practicePath.isEmpty {
                FloatingTabBar(selection: $tab).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: practicePath.isEmpty)
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.28)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 16, weight: .semibold))
                        Text(tab.title).font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.white : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == tab {
                            Capsule().fill(Theme.maroon).matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(Theme.sand.opacity(0.6), in: Capsule())
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 6)
        .background(Theme.background.opacity(0.001))
    }
}
