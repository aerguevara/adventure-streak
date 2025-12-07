import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct UserSearchView: View {
    @StateObject var viewModel = UserSearchViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Buscar usuarios...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "18181C"))
                    .cornerRadius(12)
                    .padding()
                    
                    // Results
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                        Spacer()
                        emptyStateView
                        Spacer()
                    } else if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.searchText.isEmpty {
                                    Text("Top 20 más activos")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                }
                                ForEach(viewModel.searchResults) { entry in
                                    UserSearchResultCard(entry: entry) {
                                        viewModel.toggleFollow(for: entry)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Busca a tus amigos")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Escribe su nombre para empezar")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Buscar Usuarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No se encontró ningún usuario")
                .font(.headline)
                .foregroundColor(.white)
            Text("Intenta con otro nombre")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct UserSearchResultCard: View {
    let entry: RankingEntry
    var onFollowTapped: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            if let data = entry.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else if let url = entry.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color(hex: "2C2C2E"))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: "2C2C2E"))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(entry.displayName.prefix(1).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Nivel \(entry.level)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Follow Button
            Button(action: {
                onFollowTapped?()
            }) {
                Text(entry.isFollowing ? "Siguiendo" : "Seguir")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(entry.isFollowing ? .gray : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(entry.isFollowing ? Color.white.opacity(0.1) : Color(hex: "4C6FFF"))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(hex: "18181C"))
        .cornerRadius(16)
    }
}
