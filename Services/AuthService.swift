import AuthenticationServices
import Observation
import UIKit

/// Sign in with Apple. Requires the "Sign in with Apple" capability (paid developer team).
/// Google sign-in needs the GoogleSignIn SDK + a client ID and is not wired yet.
@MainActor @Observable
final class AuthService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @ObservationIgnored private var completion: ((Result<String?, Error>) -> Void)?

    func signInWithApple(completion: @escaping (Result<String?, Error>) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.completion = completion
        controller.performRequests()
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let given = (authorization.credential as? ASAuthorizationAppleIDCredential)?.fullName?.givenName
        Task { @MainActor in
            self.completion?(.success(given))
            self.completion = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.completion?(.failure(error))
            self.completion = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
