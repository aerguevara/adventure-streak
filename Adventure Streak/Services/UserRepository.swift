import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#elseif canImport(Firebase)
import Firebase
#endif

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
    func syncUser(user: FirebaseAuth.User, name: String?, initialXP: Int? = nil, initialLevel: Int? = nil) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let userRef = db.collection("users").document(user.uid)
        
        // Simple and robust: check if name is needed, then setData(merge: true)
        userRef.getDocument(source: .default) { (document, error) in
            var data: [String: Any] = [
                "lastLogin": FieldValue.serverTimestamp()
            ]
            
            let hasXP = document?.get("xp") != nil
            let hasLevel = document?.get("level") != nil
            
            // Default values for new user part of the data if it doesn't exist
            if let document = document, !document.exists {
                data["joinedAt"] = FieldValue.serverTimestamp()
                data["email"] = user.email as Any
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
                if let email = user.email, !email.isEmpty {
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
    
    func updateTerritoryStats(userId: String, totalOwned: Int, recentWindow: Int) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        let userRef = db.collection("users").document(userId)
        userRef.setData([
            "totalCellsOwned": totalOwned,
            "recentTerritories": recentWindow
        ], merge: true)
        #endif
    }
    
    func updateFCMToken(userId: String, token: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
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
        guard let db = db as? Firestore else { return }
        
        // Use a transaction to ensure uniqueness
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let iconRef = db.collection("reserved_icons").document(icon)
            let userRef = db.collection("users").document(userId)
            
            // 1. Check if icon is already reserved by someone else
            let iconDoc: DocumentSnapshot
            do {
                iconDoc = try transaction.getDocument(iconRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            if iconDoc.exists {
                let ownerId = iconDoc.get("userId") as? String
                if ownerId != userId {
                    let error = NSError(domain: "AdventureStreak", code: 409, userInfo: [NSLocalizedDescriptionKey: "Icon already in use"])
                    errorPointer?.pointee = error
                    return nil
                }
            }
            
            // 2. Get current user to see if they already have an icon reserved
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = error as NSError
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
    #else
    // Fallback signature if FirebaseAuth missing
    func syncUser(user: Any, name: String?) {}
    func updateTerritoryStats(userId: String, totalOwned: Int, recentWindow: Int) {}
    func updateFCMToken(userId: String, token: String) {}
    func removeFCMToken(userId: String, token: String) {}
    #endif
    #if canImport(FirebaseAuth)
    func fetchUser(userId: String, completion: @escaping (User?) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion(nil)
            return
        }
        
        db.collection("users").document(userId).getDocument(source: .default) { (document, error) in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
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
    
    // NEW: Real-time observation
    func observeUser(userId: String, completion: @escaping (User?) -> Void) -> ListenerRegistration? {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return nil }
        
        return db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching user snapshot: \(error!)")
                return
            }
            
            do {
                let user = try document.data(as: User.self)
                completion(user)
            } catch {
                print("Error decoding user snapshot: \(error)")
                completion(nil)
            }
        }
        #else
        return nil
        #endif
    }
    #else
    func fetchUser(userId: String, completion: @escaping (Any?) -> Void) { completion(nil) }
    func observeUser(userId: String, completion: @escaping (Any?) -> Void) -> Any? { return nil }
    #endif
}
