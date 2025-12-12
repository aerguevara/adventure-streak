import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth

class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isSyncingData = false
    
    // Helper for nonce
    fileprivate var currentNonce: String?
    
    override init() {
        super.init()
        if let user = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.userId = user.uid
            self.userEmail = user.email
            self.userName = AuthenticationService.resolveDisplayName(for: user)
            loadDisplayNameFromRemoteIfNeeded(userId: user.uid)
            
            // Sincronizar actividades remotas si ya hay sesión persistida
            Task {
                await MainActor.run { self.isSyncingData = true }
                await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                await MainActor.run { self.isSyncingData = false }
            }
        }
    }
    
    func startSignInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signInAnonymously(completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Error signing in anonymously: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
        if let user = authResult?.user {
            self.isAuthenticated = true
            self.userId = user.uid
            self.userEmail = nil
            self.userName = "Guest Adventurer"
            
            // Sync Guest User to Firestore
            UserRepository.shared.syncUser(user: user, name: "Guest Adventurer")
            Task {
                await MainActor.run { self.isSyncingData = true }
                await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                await MainActor.run { self.isSyncingData = false }
            }
            completion(true, nil)
        } else {
            completion(false, nil)
        }
    }
    }
    
    func signInWithGoogle(completion: @escaping (Bool, Error?) -> Void) {
        // Placeholder for Google Sign In
        // Requires GoogleSignIn dependency
        print("Google Sign In requested - Implementation pending dependency check")
        // Simulate error for now or success if testing
        let error = NSError(domain: "AdventureStreak", code: 404, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In not fully configured yet."])
        completion(false, error)
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.userId = nil
            self.userName = nil
            self.userEmail = nil
            Task { @MainActor in
                ActivityStore.shared.clear()
                TerritoryStore.shared.clear()
                SocialService.shared.clear()
                GamificationService.shared.syncState(xp: 0, level: 1)
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Display Name Helpers
    private static func resolveDisplayName(for user: FirebaseAuth.User) -> String? {
        if let displayName = user.displayName, !displayName.isEmpty {
            return displayName
        }
        if let email = user.email,
           let prefix = email.split(separator: "@").first,
           !prefix.isEmpty {
            return String(prefix)
        }
        return nil
    }
    
    private func loadDisplayNameFromRemoteIfNeeded(userId: String) {
        // Skip if already have a non-empty name
        if let existing = userName, !existing.isEmpty { return }
        
        UserRepository.shared.fetchUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            if let remoteName = user?.displayName, !remoteName.isEmpty {
                DispatchQueue.main.async {
                    self.userName = remoteName
                }
            }
        }
    }
    
    /// Nombre a usar en el feed/UI con fallback a email o genérico.
    func resolvedUserName(default defaultName: String = "Aventurero") -> String {
        if let name = userName, !name.isEmpty {
            return name
        }
        if let authDisplay = Auth.auth().currentUser?.displayName,
           !authDisplay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return authDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let email = userEmail,
           let prefix = email.split(separator: "@").first,
           !prefix.isEmpty {
            return String(prefix)
        }
        return defaultName
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            // Use the specific static method found in the user's provided SDK code
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                    return
                }
                
                if let user = authResult?.user {
                    self.isAuthenticated = true
                    self.userId = user.uid
                    self.userEmail = user.email
                    
                    // Prefer existing Firestore displayName; fallback to Apple fullName; then to resolved name/email.
                    let resolvedFallback = AuthenticationService.resolveDisplayName(for: user) ?? "Aventurero"
                    let appleName: String? = {
                        guard let fullName = appleIDCredential.fullName else { return nil }
                        let formatter = PersonNameComponentsFormatter()
                        let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                        return formatted.isEmpty ? nil : formatted
                    }()
                    
                    // Set an early value to avoid nil in UI while fetching remote
                    self.userName = appleName ?? resolvedFallback
                    
                    UserRepository.shared.fetchUser(userId: user.uid) { [weak self] remoteUser in
                        guard let self = self else { return }
                        let remoteName = remoteUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let chosenName = (remoteName?.isEmpty == false) ? remoteName! : (appleName ?? resolvedFallback)
                        
                        DispatchQueue.main.async {
                        self.userName = chosenName
                    }
                    
                    // Sync without clobbering: use chosenName (remote preferred) so displayName stays consistent, and update lastLogin.
                    UserRepository.shared.syncUser(user: user, name: chosenName)
                    
                    // Backfill + parity check so remote list matches local feed/events
                    Task {
                        await MainActor.run { self.isSyncingData = true }
                        await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                        await MainActor.run { self.isSyncingData = false }
                    }
                }
            }
        }
    }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Best effort to find the window scene
        return UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first ?? ASPresentationAnchor()
    }
}
