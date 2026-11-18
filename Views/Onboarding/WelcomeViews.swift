import AuthenticationServices
import SwiftUI

struct SplashView: View {
    let onStart: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            IllustrationImage(name: "splash_illustration").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Text("SwarSathi").font(.brandTitle).foregroundStyle(Theme.ink)
                Text("Practice Indian Classical music\nat your own pace.").font(.footnote).foregroundStyle(Theme.muted)
                Spacer()
                Button("Get started", action: onStart).buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.screenPadding)
        }
    }
}

struct WelcomeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(AuthService.self) private var auth
    @State private var showGuestAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Group {
                    if UIImage(named: "logo") != nil { Image("logo").resizable().scaledToFit() }
                    else { Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Theme.maroon) }
                }
                .frame(width: 44, height: 44)
                Text("SwarSathi").font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(Theme.maroon)
            }
            .padding(.top, 40)

            Text("Welcome").font(.system(size: 34, weight: .semibold, design: .serif)).foregroundStyle(Theme.maroon)
                .padding(.top, 36)

            IllustrationImage(name: "welcome_illustration")
                .frame(height: 220).clipped().padding(.top, 24)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Button {
                    auth.signInWithApple { result in
                        switch result {
                        case .success(let name):
                            store.updateProfile { $0.isSignedIn = true; if let name { $0.name = name } }
                        case .failure(let error):
                            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
                            alertMessage = "Sign in with Apple isn’t available in this build. You can continue as a guest and sign in later."
                            showGuestAlert = true
                        }
                    }
                } label: {
                    Label("Continue with Apple", systemImage: "apple.logo")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    alertMessage = "Google sign-in isn’t connected yet. You can continue as a guest."
                    showGuestAlert = true
                } label: {
                    HStack(spacing: 8) {
                        if UIImage(named: "google_logo") != nil { Image("google_logo").resizable().scaledToFit().frame(width: 18, height: 18) }
                        else { Image(systemName: "g.circle.fill") }
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(OutlineButtonStyle())

                Text("By continuing, you agree to the Terms & Privacy Policy.")
                    .font(.caption2).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 16)
        }
        .alert("Continue as guest?", isPresented: $showGuestAlert) {
            Button("Continue as guest") { store.updateProfile { $0.isSignedIn = true } }
            Button("Cancel", role: .cancel) {}
        } message: { Text(alertMessage) }
    }
}
