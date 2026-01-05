import SwiftUI
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

struct ProfileDetailView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var workoutsViewModel: WorkoutsViewModel
    @StateObject var relationsViewModel: SocialRelationsViewModel
    
    @State private var showDebugMenu = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: RelationTab = .following
    @State private var showSignOutConfirmation = false
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var showIconPicker = false
    private let currentUserId: String? = AuthenticationService.shared.userId
    
    enum RelationTab: String, CaseIterable, Identifiable {
        case following = "Siguiendo"
        case followers = "Seguidores"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header: Avatar & Level
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarView
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(LinearGradient(
                                            colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 4)
                                )
                            
                            // Change Photo Button
                            Button {
                                showImagePicker = true
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(hex: "4C6FFF"))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .offset(x: 4, y: 4)
                        }
                        
                        VStack(spacing: 4) {
                            Text(profileViewModel.userDisplayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Label("Nivel \(profileViewModel.level)", systemImage: "bolt.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "A259FF"))
                                
                                if profileViewModel.streakWeeks > 0 {
                                    Label("\(profileViewModel.streakWeeks) semanas racha", systemImage: "flame.fill")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text(profileViewModel.userTitle)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            
                            if let joinedAt = profileViewModel.joinedAt {
                                Text("Aventurero desde \(joinedAt, style: .date)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // XP Progress Bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progreso de Nivel")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(profileViewModel.totalXP) XP")
                                .font(.caption2)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.05))
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: "4C6FFF"), Color(hex: "A259FF")], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(min(Double(profileViewModel.totalXP % 1000) / 1000.0, 1.0)))
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal)
                    
                    // Stats Grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Estadísticas")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(title: "XP Total", value: "\(profileViewModel.totalXP)", icon: "sparkles", color: .purple)
                            StatCard(title: "Zonas Totales", value: "\(profileViewModel.totalCellsConquered)", icon: "map.fill", color: .blue)
                            StatCard(title: "Esta Semana", value: "+\(profileViewModel.territoriesCount)", icon: "figure.run", color: .green)
                            StatCard(title: "Actividades", value: "\(profileViewModel.activitiesCount)", icon: "bolt.horizontal.fill", color: .yellow)
                        }
                        .padding(.horizontal)
                        
                        // Personal Records
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Récords Personales")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 12) {
                                recordItem(title: "Semana Histórica", value: String(format: "%.1f km", profileViewModel.bestWeeklyDistanceKm), icon: "trophy.fill", color: .orange)
                                recordItem(title: "Esta Semana", value: String(format: "%.1f km", profileViewModel.currentWeekDistanceKm), icon: "figure.walk", color: .blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Next Goal / Rival Card
                    if let goal = profileViewModel.nextGoal, let xpNeeded = profileViewModel.xpToNextGoal {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Próximo Objetivo")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                rivalAvatar(entry: goal)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Supera a \(goal.displayName)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Te faltan \(xpNeeded) XP esta semana para subir al puesto #\(goal.position)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(hex: "1C1C1E"))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FFD60A").opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Map Icon Action
                    VStack(spacing: 12) {
                        Button {
                            showIconPicker = true
                        } label: {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    if let icon = profileViewModel.mapIcon {
                                        Text(icon)
                                            .font(.system(size: 18))
                                    } else {
                                        Image(systemName: "map.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text("Icono del Mapa")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(profileViewModel.mapIcon ?? "Seleccionar")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(hex: "18181C"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Extra Actions: Missions
                    VStack(spacing: 12) {
                        NavigationLink(destination: MissionGuideView()) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: "5856D6").opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color(hex: "5856D6"))
                                }
                                
                                Text("Guía de Misiones")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(hex: "18181C"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Relations Tabs
                    VStack(spacing: 16) {
                        Picker("", selection: $selectedTab) {
                            ForEach(RelationTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if relationsViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 20)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(selectedTab == .following ? relationsViewModel.following : relationsViewModel.followers) { user in
                                    relationRow(for: user)
                                }
                                
                                if (selectedTab == .following ? relationsViewModel.following : relationsViewModel.followers).isEmpty {
                                    Text("Ninguno todavía")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.top, 20)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    #if DEBUG
                    VStack(spacing: 12) {
                        Button {
                            showDebugMenu = true
                        } label: {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "ladybug.fill")
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Simulación HealthKit")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(hex: "18181C"))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    #endif
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Mi Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.2))
                        .font(.title3)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            AvatarImagePicker(image: $pickedImage)
        }
        .onChange(of: pickedImage) { _, newImage in
            guard let img = newImage else { return }
            Task {
                if let data = img.resizedSquareData(maxSide: 256, quality: 0.7) {
                    await profileViewModel.uploadAvatar(imageData: data)
                }
            }
        }
        .onAppear {
            Task {
                if let userId = currentUserId {
                    await relationsViewModel.load(for: userId)
                }
            }
        }
        .confirmationDialog("Cerrar sesión", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                profileViewModel.signOut()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Estás seguro de que quieres cerrar sesión?")
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugSimulationView(workoutsViewModel: workoutsViewModel)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(viewModel: profileViewModel)
        }
    }
    
    private var avatarView: some View {
        Group {
            if let url = profileViewModel.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "1C1C1E"))
                }
            } else {
                Circle()
                    .fill(Color(hex: "1C1C1E"))
                    .overlay(
                        Text(profileViewModel.userDisplayName.prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    @ViewBuilder
    private func relationRow(for user: SocialUser) -> some View {
        HStack {
            if let data = user.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else if let url = user.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.05))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if user.level > 0 {
                    Text("Nivel \(user.level)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if user.id != currentUserId {
                Button(action: {
                    relationsViewModel.toggleFollow(userId: user.id, displayName: user.displayName)
                }) {
                    Text(user.isFollowing ? "Siguiendo" : "Seguir")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(user.isFollowing ? Color.white.opacity(0.1) : Color(hex: "4C6FFF"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(hex: "18181C"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func recordItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func rivalAvatar(entry: RankingEntry) -> some View {
        Group {
            if let data = entry.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = entry.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.1))
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Text(entry.displayName.prefix(1).uppercased())
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

#if canImport(UIKit)
struct AvatarImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AvatarImagePicker
        
        init(parent: AvatarImagePicker) {
            self.parent = parent
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { parent.dismiss() }
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
                return
            }
            if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
        }
    }
}

extension UIImage {
    func resizedSquareData(maxSide: CGFloat, quality: CGFloat) -> Data? {
        let minSide = min(size.width, size.height)
        let cropRect = CGRect(
            x: (size.width - minSide) / 2,
            y: (size.height - minSide) / 2,
            width: minSide,
            height: minSide
        )
        guard let cg = cgImage?.cropping(to: cropRect) else { return nil }
        let square = UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxSide, height: maxSide))
        let img = renderer.image { _ in
            square.draw(in: CGRect(x: 0, y: 0, width: maxSide, height: maxSide))
        }
        return img.jpegData(compressionQuality: quality)
    }
}
#endif
