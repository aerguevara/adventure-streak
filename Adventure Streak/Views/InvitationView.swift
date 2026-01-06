import SwiftUI

struct InvitationView: View {
    @ObservedObject var authService = AuthenticationService.shared
    @State private var inviteToken: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAnimatingIcon = false
    
    var body: some View {
        ZStack {
            // Fondo Inmersivo
            Color.black.ignoresSafeArea()
            
            // Reflejos Gradientes de Fondo
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -150, y: -250)
                
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: 200)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icono con Animación Sutil y Renderizado Corregido
                ZStack {
                    // Círculo de brillo de fondo
                    Circle()
                        .fill(RadialGradient(colors: [.orange.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 100))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimatingIcon ? 1.2 : 0.9)
                        .opacity(isAnimatingIcon ? 0.6 : 0.3)
                    
                    // Composición de Iconos para control total de Gradientes
                    ZStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Image(systemName: "shield.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.black)
                            .clipShape(Circle())
                            .offset(x: 35, y: 30)
                    }
                    .shadow(color: .orange.opacity(0.4), radius: 20, x: 0, y: 15)
                }
                .offset(y: isAnimatingIcon ? -10 : 10)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimatingIcon)
                .onAppear { 
                    // Delayed start to avoid animation jump
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimatingIcon = true 
                    }
                }
                
                // Textos Secundarios
                VStack(spacing: 20) {
                    Text("Acceso Exclusivo")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text("Adventure Streak está en fase privada.\nTu aventura comienza con una invitación.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 50)
                        .lineSpacing(6)
                }
                
                // Contenedor de Input Estilo Glassmorphism
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CÓDIGO DE ACCESO")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.leading, 4)
                        
                        TextField("Ingresa tu código", text: $inviteToken)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(inviteToken.isEmpty ? Color.white.opacity(0.1) : Color.orange.opacity(0.5), lineWidth: 1.5)
                            )
                            .foregroundColor(.white)
                            .accentColor(.orange)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                    }
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                    }
                    
                    Button(action: redeemInvitation) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("VALIDAR INVITACIÓN")
                                    .fontWeight(.black)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                if !inviteToken.isEmpty && !isLoading {
                                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                } else {
                                    Color.white.opacity(0.1)
                                }
                            }
                        )
                        .foregroundColor(inviteToken.isEmpty ? .white.opacity(0.3) : .white)
                        .cornerRadius(16)
                        .shadow(color: inviteToken.isEmpty ? .clear : .orange.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(inviteToken.isEmpty || isLoading)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.05))
                        .background(Blur(style: .systemThinMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: { authService.signOut() }) {
                    Text("Cerrar Sesión")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Animación del icono
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimatingIcon = true 
            }
            
            // Unificamos: No redimimos automáticamente para evitar colisiones de red
            // en entornos de red inestable (especialmente simuladores).
            if let pending = UserDefaults.standard.string(forKey: "pendingInvitationToken") {
                inviteToken = pending
                UserDefaults.standard.removeObject(forKey: "pendingInvitationToken")
                print("🎟️ [InvitationView] Token pendiente cargado: \(pending). El usuario debe pulsar Validar.")
            }
        }
    }
    
    private func redeemInvitation() {
        guard !isLoading && !inviteToken.isEmpty else { return }
        
        withAnimation {
            isLoading = true
            errorMessage = nil
        }
        
        Task {
            do {
                try await authService.redeemInvitation(token: inviteToken)
                // AuthenticationService will update isInvitationVerified on success
                // View will dismiss because parent checks authService.isInvitationVerified
            } catch {
                withAnimation {
                    errorMessage = "CÓDIGO NO VÁLIDO O EXPIRADO"
                    isLoading = false
                }
            }
        }
    }
}

// Helper para Blur Material en SwiftUI
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    InvitationView()
}
