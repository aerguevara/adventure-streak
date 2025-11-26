import Foundation
import AuthenticationServices

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService = AuthenticationService.shared
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        // The actual presentation is handled by the ASAuthorizationController in the Service.
        // We just trigger it.
        // Note: In a real app, we might want to listen to the service's state to know when to stop loading.
        // For now, we'll simulate a delay or rely on the service updating the global auth state which dismisses this view.
        authService.startSignInWithApple()
        
        // Reset loading after a delay if nothing happens (timeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.isLoading {
                self.isLoading = false
            }
        }
    }
    
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        // Call service
        authService.signInWithGoogle { [weak self] success, error in
            self?.isLoading = false
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func signInAnonymously() {
        isLoading = true
        errorMessage = nil
        
        authService.signInAnonymously { [weak self] success, error in
            self?.isLoading = false
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
}
