import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

extension Firestore {
    /// Shared Firestore instance that selects the appropriate database based on build configuration.
    static var shared: Firestore {
        #if canImport(FirebaseFirestore)
        #if DEBUG
        // Using the pre-production database for Debug builds
        return Firestore.firestore(database: "adventure-streak-pre")
        #else
        // Using the default database for Release builds
        return Firestore.firestore()
        #endif
        #else
        fatalError("FirebaseFirestore not available")
        #endif
    }
}
