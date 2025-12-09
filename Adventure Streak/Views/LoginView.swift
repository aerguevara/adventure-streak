import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Logo
                Spacer()
                    .frame(height: 60) // Padding superior ~60
                
                Image("AppIcon") // Using asset name, fallback to system if needed
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16) // App icon usually has rounded corners
                    .shadow(radius: 5)
                    .overlay(
                        // Fallback if image not found
                        Image(systemName: "map.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                            .opacity(UIImage(named: "AppIcon") == nil ? 1 : 0)
                    )
                
                // 2. App Name
                Text("Adventure Streak")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                    .foregroundColor(.primary)
                
                // 3. Tagline
                Text("Corre. Conquista. Mantén tu territorio.")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal)
                
                Spacer()
                
                // 5. Buttons
                VStack(spacing: 16) {
                    // A. Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            // Triggered when button is tapped
                        },
                        onCompletion: { result in
                            // Handled via delegate in Service, but we can catch errors here too
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .overlay(
                        // Overlay to intercept tap for ViewModel logic
                        Button(action: {
                            viewModel.signInWithApple()
                        }) {
                            Color.clear
                        }
                    )
                    
                    // B. Google Login (Custom)
                    Button(action: {
                        viewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            // G Logo
                            ZStack {
                                Color(.systemBackground)
                                Image(systemName: "g.circle.fill") // Placeholder for G logo
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.red) // Google Red-ish
                            }
                            .frame(width: 24, height: 24)
                            
                            Text("Continuar con Google")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.primary.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    // C. Guest Login (Temporary)
                    Button(action: {
                        viewModel.signInAnonymously()
                    }) {
                        Text("Entrar como invitado")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                .disabled(viewModel.isLoading)
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                Spacer()
                    .frame(height: 40)
                
                // 7. Legal Text
                Text("Al continuar aceptas los términos y la política de privacidad.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .opacity(0.5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // 8. Footer
                Text("Tu cuenta se crea automáticamente cuando inicias sesión.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.4)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
}
