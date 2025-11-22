import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Adventure Streak")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Conquer the world, one run at a time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            SignInWithAppleButton(
                onRequest: { request in
                    // Handled in Service, but button needs this closure
                    authService.startSignInWithApple()
                },
                onCompletion: { result in
                    // Handled in Service delegate
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding()
            // We override the tap gesture because the native button handles its own request,
            // but we want to route it through our Service logic which sets up the delegate.
            // Actually, the native button requires us to configure the request in `onRequest`.
            // Let's adjust: We'll use a custom button wrapper or just trigger the service.
            // For simplicity and correctness with SwiftUI's button:
            .overlay(
                Button(action: {
                    authService.startSignInWithApple()
                }) {
                    Color.clear
                }
            )
            
            Button(action: {
                authService.signInAnonymously()
            }) {
                Text("Continue as Guest")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
            }
            
            Text("Sign in to sync your territories and compete with others.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 40)
        }
    }
}
