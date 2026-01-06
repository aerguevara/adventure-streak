import SwiftUI

struct ReferralTreeView: View {
    @ObservedObject var authService = AuthenticationService.shared
    @State private var referrals: [User] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Mi Estadísticas de Invitación")) {
                    HStack {
                        Text("Cupo Total")
                        Spacer()
                        Text("\(authService.invitationQuota)")
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Invitaciones Usadas")
                        Spacer()
                        Text("\(authService.invitationCount)")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                
                Section(header: Text("Mi Árbol de Aventureros")) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if referrals.isEmpty {
                        Text("Aún no has invitado a nadie. ¡Comparte tu link!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(referrals) { user in
                            ReferralRow(user: user)
                        }
                    }
                }
                
                Section {
                    Button(action: generateAndShareInvite) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Generar y Compartir Invitación")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.orange)
                    }
                    .disabled(authService.invitationCount >= authService.invitationQuota)
                } footer: {
                    if authService.invitationCount >= authService.invitationQuota {
                        Text("Has alcanzado tu límite de invitaciones.")
                    }
                }
            }
            .navigationTitle("Comunidad")
            .onAppear(perform: loadReferrals)
        }
    }
    
    private func loadReferrals() {
        isLoading = true
        UserRepository.shared.fetchAllDescendants(for: authService.userId ?? "") { users in
            // Sort by level or path length if needed
            self.referrals = users.sorted(by: { ($0.invitationPath?.count ?? 0) < ($1.invitationPath?.count ?? 0) })
            self.isLoading = false
        }
    }
    
    private func generateAndShareInvite() {
        Task {
            do {
                if let token = try await authService.generateInvitation() {
                    // Usamos Universal Link HTTPS
                    let inviteLink = "https://adventure-streak.web.app/invite?token=\(token)"
                    shareLink(inviteLink)
                }
            } catch {
                print("Error generating invite: \(error)")
            }
        }
    }
    
    private func shareLink(_ link: String) {
        let text = "¡Únete a mi equipo en Adventure Streak! Usa mi código para entrar: \(link)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                var topController = rootVC
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                topController.present(av, animated: true)
            }
        }
    }
}

struct ReferralRow: View {
    let user: User
    
    var body: some View {
        HStack {
            let depth = (user.invitationPath?.count ?? 0) - (AuthenticationService.shared.userInvitationPathCount)
            if depth > 0 {
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .padding(.leading, 8)
                }
            }
            
            if let avatar = user.avatarURL, let url = URL(string: avatar) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                Text(user.displayName ?? "Explorador")
                    .font(.headline)
                Text("Nivel \(user.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let count = user.invitationCount, count > 0 {
                Text("\(count) 👥")
                    .font(.caption)
                    .padding(4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}
