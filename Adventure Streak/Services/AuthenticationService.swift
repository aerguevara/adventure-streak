import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    nonisolated static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var userId: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var userAvatarURL: String?
    @Published var isSyncingData = false
    
    private let userDefaults = UserDefaults.standard
    private var userListener: ListenerRegistration?
    
    // Helper for nonce
    fileprivate var currentNonce: String?
    
    nonisolated override init() {
        super.init()
        Task {
            await setupInitialSession()
        }
    }
    
    private func setupInitialSession() {
        if let user = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.userId = user.uid
            self.userEmail = user.email
            self.userName = AuthenticationService.resolveDisplayName(for: user)
            loadDisplayNameFromRemoteIfNeeded(userId: user.uid)
            Task {
                NotificationService.shared.syncCachedFCMToken(for: user.uid)
                NotificationService.shared.refreshFCMTokenIfNeeded(for: user.uid)
            }
            self.observeForceLogout(for: user.uid)
            
            // Sincronizar actividades remotas si ya hay sesión persistida
            Task {
                self.isSyncingData = true
                await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                await TerritoryRepository.shared.syncUserTerritories(userId: user.uid, store: TerritoryStore.shared)
                self.isSyncingData = false
                
                // Iniciar observación en tiempo real
                ActivityStore.shared.startObserving(userId: user.uid)
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
                Task { @MainActor in
                    completion(false, error)
                }
                return
            }
            
            if let user = authResult?.user {
                Task { @MainActor in
                    self.isAuthenticated = true
                    self.userId = user.uid
                    self.userEmail = nil
                    
                    // Realistic Name Generation
                    let adjectives = ["Veloz", "Intrépido", "Legendario", "Silencioso", "Audaz", "Infatigable", "Nómada"]
                    let nouns = ["Explorador", "Caminante", "Rastreador", "Senda", "Halcón", "Lobo", "Jaguar"]
                    let guestName = "\(nouns.randomElement() ?? "Explorador") \(adjectives.randomElement() ?? "Veloz")"
                    
                    self.userName = guestName
                    
                    NotificationService.shared.syncCachedFCMToken(for: user.uid)
                    NotificationService.shared.refreshFCMTokenIfNeeded(for: user.uid)
                    
                    self.observeForceLogout(for: user.uid)
                    
                    // Initial realistic stats for a "vibrant" first impression
                    let initialXP = 1200
                    let initialLevel = 2
                    
                    // Sync Guest User to Firestore
                    UserRepository.shared.syncUser(user: user, name: guestName, initialXP: initialXP, initialLevel: initialLevel)
                    
                    // Update local gamification state immediately
                    GamificationService.shared.syncState(xp: initialXP, level: initialLevel)
                    
                    self.isSyncingData = true
                    await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                    await TerritoryRepository.shared.syncUserTerritories(userId: user.uid, store: TerritoryStore.shared)
                    self.isSyncingData = false
                    
                    ActivityStore.shared.startObserving(userId: user.uid)
                    
                    completion(true, nil)
                }
            } else {
                Task { @MainActor in
                    completion(false, nil)
                }
            }
        }
    }
    
    func signInWithGoogle(completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(false, NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Client ID found in Firebase config"]))
            return
        }
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Find the presenting window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(false, NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "No Root ViewController found"]))
            return
        }
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error during Google Sign In: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(false, NSError(domain: "Auth", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID Token"]))
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)
            
            // Authenticate with Firebase
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Google Auth Error: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                
                Task { @MainActor in
                    self.isAuthenticated = true
                    self.userId = firebaseUser.uid
                    self.userEmail = firebaseUser.email
                    
                    // Name Resolution
                    let googleName = user.profile?.name
                    let resolvedName = googleName ?? AuthenticationService.resolveDisplayName(for: firebaseUser) ?? "Aventurero"
                    self.userName = resolvedName
                    
                    // Avatar Resolution (High Res if possible)
                    if let profileURL = user.profile?.imageURL(withDimension: 200) {
                        self.userAvatarURL = profileURL.absoluteString
                    }
                    
                    NotificationService.shared.syncCachedFCMToken(for: firebaseUser.uid)
                    NotificationService.shared.refreshFCMTokenIfNeeded(for: firebaseUser.uid)
                    self.observeForceLogout(for: firebaseUser.uid)
                    
                    // Sync User Data
                    UserRepository.shared.fetchUser(userId: firebaseUser.uid) { [weak self] remoteUser in
                        guard let self = self else { return }
                        
                        let initialXP = 0
                        let initialLevel = 1
                        
                        // Use remote name if it exists and is not empty, otherwise use Google name
                        let finalName = (remoteUser?.displayName?.isEmpty == false) ? remoteUser!.displayName! : resolvedName
                        self.userName = finalName
                        
                        // RECOVERY LOGIC: Use custom claims if provided in the token (preserved after reinstall)
                        Task {
                            let result = try? await firebaseUser.getIDTokenResult()
                            let recoveryXP = result?.claims["xp"] as? Int
                            let recoveryLevel = result?.claims["level"] as? Int
                            
                            if let xp = recoveryXP {
                                print("[AuthenticationService] Found recovery XP in Auth claims (Google): \(xp)")
                            }

                            // Sync with backend
                            UserRepository.shared.syncUser(user: firebaseUser, name: finalName, initialXP: recoveryXP, initialLevel: recoveryLevel)
                            
                            // Update Gamification
                            let isNewOrDummy = remoteUser == nil || (remoteUser?.xp == 0 && remoteUser?.joinedAt == nil)
                            if isNewOrDummy {
                                GamificationService.shared.syncState(xp: recoveryXP ?? 0, level: recoveryLevel ?? 1)
                            } else if let remoteUser = remoteUser {
                                GamificationService.shared.syncState(xp: remoteUser.xp, level: remoteUser.level)
                            }
                            
                            // Sync Activities
                            self.isSyncingData = true
                            await ActivityRepository.shared.ensureRemoteParity(userId: firebaseUser.uid, territoryStore: TerritoryStore.shared)
                            await TerritoryRepository.shared.syncUserTerritories(userId: firebaseUser.uid, store: TerritoryStore.shared)
                            self.isSyncingData = false
                            
                            ActivityStore.shared.startObserving(userId: firebaseUser.uid)
                            
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }
    
    func signOut() {
        let currentUserId = self.userId
        do {
            try Auth.auth().signOut()
            if let currentUserId {
                Task {
                    NotificationService.shared.removeActiveToken(for: currentUserId)
                }
            }
            self.isAuthenticated = false
            self.userId = nil
            self.userName = nil
            self.userAvatarURL = nil
            self.userEmail = nil
            userListener?.remove()
            userListener = nil
            Task { @MainActor in
                ActivityStore.shared.clear()
                TerritoryStore.shared.clear()
                SocialService.shared.clear()
                PendingRouteStore.shared.clear()
                GamificationService.shared.syncState(xp: 0, level: 1)
                ActivityStore.shared.stopObserving()
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
        UserRepository.shared.fetchUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            
            if let user = user {
                let remoteName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let remoteName = remoteName, !remoteName.isEmpty {
                    DispatchQueue.main.async {
                        self.userName = remoteName
                        self.userAvatarURL = user.avatarURL
                    }
                }
                
                // RESTORE ONBOARDING DATE: If remote joinedAt exists, we reconstruct the original discovery window.
                if let joinedAt = user.joinedAt {
                    let days = GameConfigService.shared.config.workoutLookbackDays
                    // The actual "history floor" is JoinedAt - 30 days (initial discovery window)
                    let firstDiscoveryStart = Calendar.current.date(
                        byAdding: .day,
                        value: -days,
                        to: joinedAt
                    ) ?? joinedAt
                    
                    let remoteTimestamp = firstDiscoveryStart.timeIntervalSince1970
                    let localTimestamp = self.userDefaults.double(forKey: "onboardingCompletionDate")
                    
                    // Restore if local is missing or remote-derived is older (more inclusive)
                    if localTimestamp == 0 || remoteTimestamp < localTimestamp {
                        self.userDefaults.set(remoteTimestamp, forKey: "onboardingCompletionDate")
                        print("[AuthenticationService] Restored historic discovery window from Firestore: \(firstDiscoveryStart)")
                    }
                }
            } else {
                // User document missing (e.g. after DB wipe). Re-sync from Auth data.
                print("Remote user missing. Re-syncing from Auth...")
                if let currentUser = Auth.auth().currentUser {
                    let name = AuthenticationService.resolveDisplayName(for: currentUser) ?? "Aventurero"
                    UserRepository.shared.syncUser(user: currentUser, name: name)
                    // Reset UI name just in case
                    DispatchQueue.main.async {
                        self.userName = name
                    }
                }
            }
        }
    }
    
    /// Nombre a usar en el feed/UI con fallback a email o genérico.
    func resolvedUserName(default defaultName: String = "Aventurero") -> String {
        if let name = userName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let authDisplay = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authDisplay.isEmpty {
            return authDisplay
        }
        if let email = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           let prefix = email.split(separator: "@").first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prefix.isEmpty {
            return String(prefix)
        }
        return defaultName
    }
    
    // MARK: - Remote logout
    private func observeForceLogout(for userId: String) {
        userListener?.remove()
        #if canImport(FirebaseFirestore)
        userListener = UserRepository.shared.observeUser(userId: userId) { [weak self] user in
            guard let self, let user else { return }
            // Treat missing as 0 so a server-side set to 0 forces logout once
            let remoteVersion = user.forceLogoutVersion ?? 0
            
            // Default to -1 so that a remoteVersion of 0 triggers once for everyone after an update
            let key = self.forceLogoutKey(for: userId)
            let lastSeen = self.userDefaults.object(forKey: key) as? Int ?? -1
            
            if lastSeen == -1 {
                // First time observing this user's force logout version. 
                // We sync with remote to avoid immediate logout.
                print("Force logout: First sync for user \(userId), setting lastSeen to \(remoteVersion)")
                self.userDefaults.set(remoteVersion, forKey: key)
                return
            }
            
            if remoteVersion > lastSeen {
                print("Force logout triggered for user \(userId): remoteVersion \(remoteVersion) > lastSeen \(lastSeen)")
                self.userDefaults.set(remoteVersion, forKey: key)
                self.signOut()
            } else {
                print("Force logout check for user \(userId): remoteVersion \(remoteVersion), lastSeen \(lastSeen) -> no action")
            }
        }
        #endif
    }
    
    private func forceLogoutKey(for userId: String) -> String {
        "forceLogoutVersion_seen_\(userId)"
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
                
                guard let user = authResult?.user else { return }
                
                Task { @MainActor in
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
                    
                    NotificationService.shared.syncCachedFCMToken(for: user.uid)
                    NotificationService.shared.refreshFCMTokenIfNeeded(for: user.uid)
                    self.observeForceLogout(for: user.uid)
                    
                    // Prefetch remote user to avoid clobbering existing name if it's a return login
                    UserRepository.shared.fetchUser(userId: user.uid) { [weak self] remoteUser in
                        guard let self = self else { return }
                        let remoteName = remoteUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let chosenName = (remoteName?.isEmpty == false) ? remoteName! : (appleName ?? resolvedFallback)
                        
                        self.userName = chosenName
                        self.userAvatarURL = remoteUser?.avatarURL
                        
                        // RECOVERY LOGIC: Use custom claims if provided in the token (preserved after reinstall)
                        Task {
                            let result = try? await user.getIDTokenResult()
                            let recoveryXP = result?.claims["xp"] as? Int
                            let recoveryLevel = result?.claims["level"] as? Int
                            
                            if let xp = recoveryXP {
                                print("[AuthenticationService] Found recovery XP in Auth claims: \(xp)")
                            }

                            // Sync with robustness (will merge if exists, create if not)
                            UserRepository.shared.syncUser(user: user, name: chosenName, initialXP: recoveryXP, initialLevel: recoveryLevel)
                            
                            // Ensure local gamification state is immediate
                            // If user is nil OR was partially created (missing XP and join date), apply initial/recovery stats
                            let isNewOrDummy = remoteUser == nil || (remoteUser?.xp == 0 && remoteUser?.joinedAt == nil)
                            
                            if isNewOrDummy {
                                GamificationService.shared.syncState(xp: recoveryXP ?? 0, level: recoveryLevel ?? 1)
                            } else if let remoteUser = remoteUser {
                                GamificationService.shared.syncState(xp: remoteUser.xp, level: remoteUser.level)
                            }
                            
                            self.isSyncingData = true
                            await ActivityRepository.shared.ensureRemoteParity(userId: user.uid, territoryStore: TerritoryStore.shared)
                            await TerritoryRepository.shared.syncUserTerritories(userId: user.uid, store: TerritoryStore.shared)
                            self.isSyncingData = false
                            
                            ActivityStore.shared.startObserving(userId: user.uid)
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
