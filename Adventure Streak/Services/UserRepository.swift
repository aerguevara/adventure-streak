import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#elseif canImport(Firebase)
import Firebase
#endif

class UserRepository: ObservableObject {
    static let shared = UserRepository()
    
    private var db: Any?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
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
    func syncUser(user: FirebaseAuth.User, name: String?) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // User exists: only update displayName if missing/empty, always bump lastLogin
                var data: [String: Any] = [
                    "lastLogin": FieldValue.serverTimestamp()
                ]
                
                let existingName = (document.get("displayName") as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let name = name,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   (existingName == nil || existingName?.isEmpty == true) {
                    data["displayName"] = name
                }
                
                // Keep avatarURL if already set; no change here
                
                userRef.updateData(data)
            } else {
                // Create new user
                let newUser = User(
                    id: user.uid,
                    email: user.email,
                    displayName: name ?? "Adventurer",
                    joinedAt: Date(),
                    avatarURL: nil
                )
                
                do {
                    try userRef.setData(from: newUser)
                } catch {
                    print("Error creating user: \(error)")
                }
            }
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
            "fcmTokens": FieldValue.arrayUnion([token])
        ], merge: true)
        #endif
    }
    #else
    // Fallback signature if FirebaseAuth missing
    func syncUser(user: Any, name: String?) {}
    func updateTerritoryStats(userId: String, totalOwned: Int, recentWindow: Int) {}
    func updateFCMToken(userId: String, token: String) {}
    #endif
    #if canImport(FirebaseAuth)
    func fetchUser(userId: String, completion: @escaping (User?) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else {
            completion(nil)
            return
        }
        
        db.collection("users").document(userId).getDocument { (document, error) in
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
