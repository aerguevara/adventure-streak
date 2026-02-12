import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum IncidentType: String, Codable, CaseIterable {
    case gpsIssue = "gps_issue"
    case territoryMissing = "territory_missing"
    case xpCalculation = "xp_calculation"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .gpsIssue: return "Problema GPS / Ruta"
        case .territoryMissing: return "Territorios no capturados"
        case .xpCalculation: return "Error en cálculo de XP"
        case .other: return "Otro problema"
        }
    }
}

@MainActor
class SupportService: ObservableObject {
    static let shared = SupportService()
    
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var isSubmitting: Bool = false
    
    private var db: Any? {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }
    
    private init() {}
    
    func reportWorkoutIncident(activityId: UUID, type: IncidentType, description: String = "") {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let currentUserId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        isSubmitting = true
        
        let reportData: [String: Any] = [
            "reporterId": currentUserId,
            "activityId": activityId.uuidString,
            "type": type.rawValue,
            "description": description,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending",
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        db.collection("incidents").addDocument(data: reportData) { [weak self] error in
            guard let self = self else { return }
            self.isSubmitting = false
            
            if let error = error {
                print("[Support] Error sending incident: \(error.localizedDescription)")
                self.alertMessage = "Error al enviar el reporte. Inténtalo de nuevo."
            } else {
                print("[Support] Incident reported for activity \(activityId.uuidString)")
                self.alertMessage = "Incidencia reportada correctamente. El equipo lo revisará pronto."
            }
            self.showAlert = true
        }
        #endif
    }
}
