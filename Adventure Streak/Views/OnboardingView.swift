import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "000000").ignoresSafeArea()
            
            VStack(spacing: 18) {
                Spacer()
                
                Image(systemName: iconName(for: viewModel.currentStep))
                    .font(.system(size: viewModel.currentStep == .done ? 90 : 70, weight: .bold))
                    .foregroundColor(Color(hex: "4C6FFF"))
                    .padding(.bottom, 4)
                
                Text(title(for: viewModel.currentStep))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                Text(subtitle(for: viewModel.currentStep))
                    .font(.body)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                VStack(spacing: 12) {
                    ProgressView(value: progress(for: viewModel.currentStep))
                        .tint(Color(hex: "4C6FFF"))
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                    
                    if viewModel.currentStep == .done {
                        Button(action: {
                            viewModel.finish()
                        }) {
                            Text("Ir a la app")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "3DF68B"), Color(hex: "4C6FFF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            handleAction(for: viewModel.currentStep)
                        }) {
                            Text(buttonTitle(for: viewModel.currentStep))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        
                        Button("Saltar este paso") {
                            viewModel.advance()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "4C6FFF"))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func handleAction(for step: PermissionStep) {
        switch step {
        case .intro:
            viewModel.advance()
        case .health:
            viewModel.requestHealth()
        case .location:
            viewModel.requestLocation()
        case .notifications:
            viewModel.requestNotifications()
        case .done:
            break
        }
    }
    
    private func title(for step: PermissionStep) -> String {
        switch step {
        case .intro: return "Antes de comenzar"
        case .health: return "Permiso de Salud"
        case .location: return "Permiso de Ubicación"
        case .notifications: return "Notificaciones"
        case .done: return "¡Listo!"
        }
    }
    
    private func subtitle(for step: PermissionStep) -> String {
        switch step {
        case .intro:
            return "Te guiaremos paso a paso para pedir los permisos necesarios. Podrás aceptarlos uno a uno."
        case .health:
            return "Necesitamos leer tus entrenos de Salud para importarlos y calcular XP y territorios."
        case .location:
            return "Usamos tu ubicación para trazar rutas y asignar territorios mientras entrenas."
        case .notifications:
            return "Te avisaremos cuando detectemos nuevos entrenos y para recordarte tus streaks."
        case .done:
            return "Permisos configurados. ¡Empecemos la aventura!"
        }
    }
    
    private func buttonTitle(for step: PermissionStep) -> String {
        switch step {
        case .intro: return "Comenzar"
        case .health: return "Permitir Salud"
        case .location: return "Permitir Ubicación"
        case .notifications: return "Permitir Notificaciones"
        case .done: return "Continuar"
        }
    }
    
    private func iconName(for step: PermissionStep) -> String {
        switch step {
        case .intro: return "sparkles"
        case .health: return "heart.circle.fill"
        case .location: return "location.circle.fill"
        case .notifications: return "bell.circle.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
    
    private func progress(for step: PermissionStep) -> Double {
        let total = Double(PermissionStep.allCases.count - 1) // exclude done
        let current = min(Double(step.rawValue), total)
        return current / total
    }
}
