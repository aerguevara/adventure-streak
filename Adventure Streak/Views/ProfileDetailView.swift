import SwiftUI
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

struct ProfileDetailView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    @StateObject var relationsViewModel: SocialRelationsViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: RelationTab = .following
    @State private var showSignOutConfirmation = false
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    private let currentUserId: String? = AuthenticationService.shared.userId
    
    enum RelationTab: String, CaseIterable, Identifiable {
        case following = "Siguiendo"
        case followers = "Seguidores"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            header
            
            Picker("", selection: $selectedTab) {
                ForEach(RelationTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if relationsViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(selectedTab == .following ? relationsViewModel.following : relationsViewModel.followers) { user in
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                if user.level > 0 {
                                    Text("Nivel \(user.level)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if user.id != currentUserId {
                                Button(action: {
                                    relationsViewModel.toggleFollow(userId: user.id, displayName: user.displayName)
                                }) {
                                    Text(user.isFollowing ? "Siguiendo" : "Seguir")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(user.isFollowing ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless) // Limita el tap solo al botón
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                if let userId = currentUserId {
                    await relationsViewModel.load(for: userId)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
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
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            if let url = profileViewModel.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }
            Button {
                showImagePicker = true
            } label: {
                VStack(spacing: 4) {
                    Text("Cambiar foto")
                        .font(.footnote.bold())
                    Text("Usa la edición nativa para recortar.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
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
            
            Text(profileViewModel.userDisplayName)
                .font(.title2.bold())
            Text(profileViewModel.userTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                StatMini(title: "Nivel", value: "\(profileViewModel.level)")
                StatMini(title: "XP", value: "\(profileViewModel.totalXP)")
                StatMini(title: "Territorios", value: "\(profileViewModel.territoriesCount)")
            }
        }
        .padding(.horizontal)
    }
}

private struct StatMini: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
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
