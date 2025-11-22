import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

class UserRepository: ObservableObject {
    static let shared = UserRepository()
    
    private var db: Any?
    
    init() {
        #if canImport(FirebaseFirestore)
        db = Firestore.firestore()
        #endif
    }
    
    #if canImport(FirebaseAuth)
    func syncUser(user: FirebaseAuth.User, name: String?) {
        #if canImport(FirebaseFirestore)
        guard let db = db as? Firestore else { return }
        
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // User exists, maybe update last login
                userRef.updateData([
                    "lastLogin": FieldValue.serverTimestamp()
                ])
            } else {
                // Create new user
                let newUser = User(
                    id: user.uid,
                    email: user.email ?? "",
                    displayName: name ?? "Adventurer",
                    joinedAt: Date()
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
    #else
    // Fallback signature if FirebaseAuth missing
    func syncUser(user: Any, name: String?) {}
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
    #else
    func fetchUser(userId: String, completion: @escaping (Any?) -> Void) { completion(nil) }
    #endif
}
