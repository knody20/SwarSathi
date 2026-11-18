import SwiftUI

@main
struct SwarSaathiApp: App {
    @State private var store = ProgressStore()
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .tint(Theme.maroon)
                // Figma is light-only. Dark appearance is a planned phase.
                .preferredColorScheme(.light)
        }
    }
}
