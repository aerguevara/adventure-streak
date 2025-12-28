import SwiftUI

struct IconPickerView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    let icons = [
        "🚩", "🚴‍♂️", "🏃‍♂️", "🚶‍♂️", "🧗‍♂️", "🚣‍♂️", "🏊‍♂️", "🏄‍♂️",
        "⛷", "🏂", "🚵‍♂️", "🥾", "🏹", "🎣", "⛺️", "🏔",
        "🌄", "🔥", "🦅", "🐺", "🐻", "🦄", "🐉", "⚔️",
        "🛡", "🏺", "💎", "🧭", "🗺", "🔭", "🛸", "🚀"
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Elige tu icono único de aventurero")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        Text("Este icono te representará en el mapa y en tus territorios conquistados. ¡Elige sabiamente, no puede haber dos iguales!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(icons, id: \.self) { icon in
                                iconButton(icon)
                            }
                        }
                        .padding()
                    }
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("Seleccionar Icono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchReservedIcons()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK") {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }
    
    private func iconButton(_ icon: String) -> some View {
        let isSelected = viewModel.mapIcon == icon
        let isTaken = viewModel.reservedIcons.contains(icon) && !isSelected
        
        return Button {
            Task {
                await viewModel.updateMapIcon(icon)
            }
        } label: {
            Text(icon)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    if isTaken {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Circle().fill(Color.black))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .disabled(isTaken || viewModel.isLoading)
        .opacity(isTaken ? 0.3 : 1.0)
    }
}
