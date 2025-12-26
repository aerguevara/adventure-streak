import SwiftUI

struct DebugSimulationView: View {
    @ObservedObject var hkManager = HealthKitManager.shared
    @ObservedObject var workoutsViewModel: WorkoutsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section(header: Text("HealthKit Simulation").foregroundColor(.gray)) {
                        Toggle("Modo Simulación", isOn: $hkManager.isSimulationMode)
                            .tint(.purple)
                        
                        if hkManager.isSimulationMode {
                            Text("Los entrenos se cargarán desde la colección Firestore 'debug_mock_workouts' en lugar de HealthKit.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if hkManager.isSimulationMode {
                        Section {
                            Button {
                                Task {
                                    await workoutsViewModel.refresh()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise.icloud.fill")
                                    Text("Sincronizar Mock Workouts")
                                }
                                .foregroundColor(.purple)
                            }
                        } footer: {
                            Text("Esto disparará el flujo completo de HealthKitManager usando el MockProvider.")
                        }
                    }
                }
                .preferredColorScheme(.dark)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
