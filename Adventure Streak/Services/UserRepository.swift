import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#endif
#if canImport(FirebaseAuth)
@preconcurrency import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#elseif canImport(Firebase)
import Firebase
#endif

enum UserError: LocalizedError {
    case iconAlreadyInUse
    case firestoreNotAvailable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iconAlreadyInUse:
            return "Icon already in use"
        case .firestoreNotAvailable:
            return "Firestore not available"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
class UserRepository: ObservableObject {
    nonisolated static let shared = UserRepository()
    
    nonisolated private let db: Any? = {
        #if canImport(FirebaseFirestore)
        return Firestore.shared
        #else
        return nil
        #endif
    }()
    
    nonisolated init() {}
    
    private var storage: Storage? {
        #if canImport(FirebaseStorage)
        return Storage.storage()
        #elseif canImport(Firebase)
        return Storage.storage()
        #else
        return nil
        #endif
    }
    
    #if canImport(FirebaseAuth)
    func syncUser(user: FirebaseAuth.User, name: String?, initialXP: Int? = nil, initialLevel: Int? = nil, invitationVerified: Bool? = nil) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let userRef = db.collection("users").document(user.uid)
        let userEmail = user.email

        // Simple and robust: check if name is needed, then setData(merge: true)
        userRef.getDocument(source: .default) { (document, error) in
            var data: [String: Any] = [
                "lastLogin": FieldValue.serverTimestamp()
            ]
            
            // Persist invitation verification if provided
            if let invitationVerified = invitationVerified {
                data["invitationVerified"] = invitationVerified
            }
            
            let hasXP = document?.get("xp") != nil
            let hasLevel = document?.get("level") != nil
            
            // Default values for new user part of the data if it doesn't exist
            if let document = document, !document.exists {
                data["joinedAt"] = FieldValue.serverTimestamp()
                data["email"] = userEmail as Any
                data["xp"] = initialXP ?? 0
                data["level"] = initialLevel ?? 1
                data["displayName"] = name ?? "Aventurero"
            } else if let document = document, document.exists {
                // Check for missing critical stats (e.g. if another service created the doc with just a token)
                if !hasXP {
                    data["xp"] = initialXP ?? 0
                }
                if !hasLevel {
                    data["level"] = initialLevel ?? 1
                }
                if document.get("joinedAt") == nil {
                    data["joinedAt"] = FieldValue.serverTimestamp()
                }

                // ALWAYS update email if we have one and it's missing or different (implicitly by merge)
                if let email = userEmail, !email.isEmpty {
                    data["email"] = email
                }

                let existingName = (document.get("displayName") as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let name = name,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   (existingName == nil || existingName?.isEmpty == true) {
                    data["displayName"] = name
                }
            }
            
            userRef.setData(data, merge: true)
        }
        #endif
    }
    
    
    func updateFCMToken(userId: String, token: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore, Auth.auth().currentUser != nil else { return }
        let userRef = db.collection("users").document(userId)
        userRef.setData([
            // Mantener solo el token activo de este dispositivo (campo string)
            "fcmTokens": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
            // Resetear flags de refresh al subir token
            "needsTokenRefresh": false,
            "needsTokenRefreshAt": FieldValue.delete()
        ], merge: true)
        #endif
    }
    
    func removeFCMToken(userId: String, token: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let userRef = db.collection("users").document(userId)
        // Se elimina el campo completo porque ahora es un string (el parámetro se ignora)
        userRef.setData([
            "fcmTokens": FieldValue.delete()
        ], merge: true)
        #endif
    }
    
    // MARK: - Map Icon Management
    
    func checkIconAvailability(icon: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return false }
        do {
            let doc = try await db.collection("reserved_icons").document(icon).getDocument()
            return !doc.exists
        } catch {
            print("Error checking icon availability: \(error)")
            return false
        }
        #else
        return false
        #endif
    }
    
    func fetchReservedIcons() async -> Set<String> {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return [] }
        do {
            let snapshot = try await db.collection("reserved_icons").getDocuments()
            return Set(snapshot.documents.map { $0.documentID })
        } catch {
            print("Error fetching reserved icons: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    func updateUserMapIcon(userId: String, icon: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { 
            throw UserError.firestoreNotAvailable 
        }
        
        // Use transaction pattern compatible with the current environment (non-throwing closure)
        _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let iconRef = db.collection("reserved_icons").document(icon)
            let userRef = db.collection("users").document(userId)
            
            // 1. Check if icon is already reserved by someone else
            guard let iconDoc = try? transaction.getDocument(iconRef) else {
                return nil
            }
            
            if iconDoc.exists {
                let ownerId = iconDoc.get("userId") as? String
                if ownerId != userId {
                    errorPointer?.pointee = UserError.iconAlreadyInUse as NSError
                    return nil
                }
            }
            
            // 2. Get current user to see if they already have an icon reserved
            guard let userDoc = try? transaction.getDocument(userRef) else {
                return nil
            }
            
            if let previousIcon = userDoc.get("mapIcon") as? String, previousIcon != icon {
                // Delete previous reservation
                let previousIconRef = db.collection("reserved_icons").document(previousIcon)
                transaction.deleteDocument(previousIconRef)
            }
            
            // 3. Set new reservation and update user
            transaction.setData([
                "userId": userId,
                "reservedAt": FieldValue.serverTimestamp()
            ], forDocument: iconRef)
            
            transaction.updateData(["mapIcon": icon], forDocument: userRef)
            
            return nil
        })
        #endif
    }

    func acknowledgeDecReset(userId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let userRef = db.collection("users").document(userId)
        let data: [String: Any] = [
            "hasAcknowledgedDecReset": true
        ]
        try await userRef.updateData(data)
        #endif
    }
    
    func acknowledgeSeason(userId: String, seasonId: String, resetDate: Date? = nil) async throws {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let userRef = db.collection("users").document(userId)
        var data: [String: Any] = [
            "lastAcknowledgeSeasonId": seasonId,
            "hasAcknowledgedDecReset": true // For legacy compatibility
        ]
        if let resetDate = resetDate {
            data["lastAcknowledgedResetAt"] = resetDate
        }
        try await userRef.updateData(data)
        #endif
    }

    func fetchUser(userId: String, source: FirestoreSource = .default, completion: @escaping (User?) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion(nil)
            return
        }
        
        db.collection("users").document(userId).getDocument(source: source) { (document, error) in
            if let document = document, document.exists {
                do {
                    var user = try document.data(as: User.self)
                    user.id = document.documentID
                    completion(user)
                } catch {
                    print("Error decoding user: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
        #else
        completion(nil)
        #endif
    }
    
    func getUser(userId: String) async -> User? {
        await withCheckedContinuation { continuation in
            fetchUser(userId: userId) { user in
                continuation.resume(returning: user)
            }
        }
    }
    
    private var lastObservedResetState: Bool?
    
    // NEW: Real-time observation
    func observeUser(userId: String, completion: @escaping (User?) -> Void) -> ListenerRegistration? {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return nil }
        
        // Reset local state tracking when starting a new observer
        self.lastObservedResetState = nil
        
        return db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching user snapshot: \(error!)")
                return
            }
            
            do {
                var user = try document.data(as: User.self)
                // FORCE ID ASSIGNMENT: Custom init(from:) in User model bypasses @DocumentID auto-mapping
                user.id = document.documentID
                
                // delegate evaluation to SeasonManager (Gatekeeper)
                SeasonManager.shared.evaluateResetStatus(user: user, config: GameConfigService.shared.config)
                
                completion(user)
            } catch {
                print("❌ UserRepository: Decoding error for user \(userId): \(error)")
                completion(nil)
            }
        }
        #else
        return nil
        #endif
    }
    
    func fetchReferrals(for userId: String, completion: @escaping ([User]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        db.collection("users")
            .whereField("invitedBy", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching referrals: \(error)")
                    completion([])
                    return
                }
                
                let users = snapshot?.documents.compactMap { doc -> User? in
                    try? doc.data(as: User.self)
                } ?? []
                completion(users)
            }
        #else
        completion([])
        #endif
    }

    func fetchAllDescendants(for userId: String, completion: @escaping ([User]) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion([])
            return
        }
        
        db.collection("users")
            .whereField("invitationPath", arrayContains: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching descendants: \(error)")
                    completion([])
                    return
                }
                
                let users = snapshot?.documents.compactMap { doc -> User? in
                    try? doc.data(as: User.self)
                } ?? []
                completion(users)
            }
        #else
        completion([])
        #endif
    }
    #else
    // Fallback if FirebaseAuth missing
    func syncUser(user: Any, name: String?) {}
    func updateFCMToken(userId: String, token: String) {}
    func removeFCMToken(userId: String, token: String) {}
    func fetchUser(userId: String, completion: @escaping (Any?) -> Void) { completion(nil) }
    func observeUser(userId: String, completion: @escaping (Any?) -> Void) -> Any? { return nil }
    #endif
}
