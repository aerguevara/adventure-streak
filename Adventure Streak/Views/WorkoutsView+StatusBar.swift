
import SwiftUI

extension WorkoutsView {
    var processingStatusBar: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Procesando actividades...")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if viewModel.importTotal > 0 {
                    Text("\(viewModel.importProcessed) de \(viewModel.importTotal) completadas")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.9))
        .cornerRadius(12)
        .padding()
        .shadow(radius: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: viewModel.importProcessed)
    }
}
