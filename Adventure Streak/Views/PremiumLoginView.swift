import SwiftUI
import AuthenticationServices

struct PremiumLoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 1. Background Image
            Image("background_login")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // 2. Global Dark Overlay
            ZStack {
                Color.black.opacity(0.4) // Darker for legibility
                    .ignoresSafeArea()
                
                // Bottom Gradient
                LinearGradient(
                    colors: [.black.opacity(0.95), .black.opacity(0.4), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 3. Logo & Branding
                VStack(spacing: 24) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle()) // Guaranteed Circle
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 8) {
                        Text("Adventure Streak")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                        
                        Text("Corre. Conquista. Mantén tu territorio.")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                }
                .padding(.bottom, 20)
                
                // Spacer to separate logo from buttons
                Spacer()
                
                // 4. Buttons (Fixed Width 280pt - Guaranteed Narrow)
                VStack(spacing: 16) {
                    // Apple Sign In (Original Black)
                    SignInWithAppleButton(
                        onRequest: { _ in },
                        onCompletion: { _ in }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 330, height: 50) // Fixed Width
                    .clipShape(Capsule())
                    .overlay(
                        Button(action: { viewModel.signInWithApple() }) { Color.clear }
                    )
                    
                    // Google Sign In
                    Button(action: {
                        viewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.red)
                            
                            Text("Continuar con Google")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 330, height: 50) // Fixed Width
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 12)
                
                Text("Se requiere un código de invitación para entrar.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 28)
                
                // 5. Footer
                VStack(spacing: 4) {
                    Text("Al continuar aceptas los términos y la política de privacidad.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
    }
}
