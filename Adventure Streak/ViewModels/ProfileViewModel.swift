import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseStorage)
import FirebaseStorage
#elseif canImport(Firebase)
import Firebase
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(UIKit)
import UIKit
#endif

struct TerritoryInventoryItem: Identifiable {
    let id: String // activityId
    let locationLabel: String
    let territories: [TerritoryCell]
    let expiresAt: Date
}

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var userDisplayName: String = "Aventurero"
    @Published var avatarURL: URL? = nil
    @Published var level: Int = 1
    @Published var totalXP: Int = 0
    @Published var nextLevelXP: Int = 1000
    @Published var xpProgress: Double = 0.0
    @Published var streakWeeks: Int = 0
    @Published var territoriesCount: Int = 0
    @Published var activitiesCount: Int = 0
    @Published var totalCellsConquered: Int = 0
    @Published var totalHistoricalConquered: Int = 0
    @Published var totalStolen: Int = 0
    @Published var totalDefended: Int = 0
    @Published var totalRecaptured: Int = 0
    @Published var territoryInventory: [TerritoryInventoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Rivals
    @Published var recentTheftVictims: [Rival] = []
    @Published var recentThieves: [Rival] = []
    
    // MARK: - Computed Properties
    var userTitle: String {
        switch level {
        case 1...5: return "Explorador Novato"
        case 6...10: return "Rastreador"
        case 11...20: return "Pionero"
        case 21...30: return "Explorador"
        case 31...50: return "Conquistador"
        case 51...99: return "Leyenda"
        default: return "Novato"
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    let activityStore: ActivityStore
    let territoryStore: TerritoryStore
    private let userRepository: UserRepository
    private let authService: AuthenticationService
    private let gamificationService: GamificationService
    private let configService: GameConfigService
    #if canImport(FirebaseStorage)
    private let storage = Storage.storage()
    #endif
    
    // MARK: - Init
    init(activityStore: ActivityStore, 
         territoryStore: TerritoryStore, 
         userRepository: UserRepository = .shared,
         authService: AuthenticationService = .shared,
         gamificationService: GamificationService = .shared,
         configService: GameConfigService) {
        self.activityStore = activityStore
        self.territoryStore = territoryStore
        self.userRepository = userRepository
        self.authService = authService
        self.gamificationService = gamificationService
        self.configService = configService
        
        // Initial load
        Task {
            await configService.loadConfigIfNeeded()
            await MainActor.run {
                self.fetchProfileData()
            }
        }
        
        // Observe GamificationService for real-time updates
        setupObservers()
        
        configService.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalStats()
            }
            .store(in: &cancellables)
    }
    
    private func setupObservers() {
        // When GamificationService updates (e.g. after activity), update local UI
        gamificationService.$currentXP
            .receive(on: RunLoop.main)
            .sink { [weak self] xp in
                self?.totalXP = xp
            }
            .store(in: &cancellables)
            
        gamificationService.$currentLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.level = level
            }
            .store(in: &cancellables)
            
        // Re-calculate progress when XP/Level changes
        gamificationService.$currentXP
            .combineLatest(gamificationService.$currentLevel)
            .receive(on: RunLoop.main)
            .sink { [weak self] (xp, level) in
                guard let self = self else { return }
                self.nextLevelXP = self.gamificationService.xpForNextLevel(level: level)
                self.xpProgress = self.gamificationService.progressToNextLevel(currentXP: xp, currentLevel: level)
            }
            .store(in: &cancellables)
        
        // Recalculate local stats whenever activities or territories change
        activityStore.$activities
            .combineLatest(territoryStore.$conqueredCells)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.refreshLocalStats()
            }
            .store(in: &cancellables)
            
        // NEW: React to login/logout
        authService.$userId
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                if userId != nil {
                    print("ProfileViewModel: userId found, fetching profile data...")
                    self?.fetchProfileData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    func fetchProfileData() {
        isLoading = true
        errorMessage = nil
        
        // 1. Refresh local stats
        refreshLocalStats()
        
        // 2. Fetch remote user profile (Real-time)
        guard let userId = authService.userId else {
            isLoading = false
            return
        }
        
        print("DEBUG: Observing User ID: \(userId)")
        
        // Remove existing listener if any
        // (In a real app we'd track the listener registration to remove it on deinit)
        
        _ = userRepository.observeUser(userId: userId) { [weak self] user in
            guard let self = self else { return }
            self.isLoading = false
            
            if let user = user {
                print("DEBUG: Fetched user (ID: \(user.id ?? "nil")): \(user.displayName ?? "nil"), XP: \(user.xp), Level: \(user.level)")
                self.updateWithUser(user)
            } else {
                print("DEBUG: Could not fetch user profile or user is nil for ID: \(userId)")
            }
        }
    }
    
    func signOut() {
        // Clear local data to allow fresh import for next user
        activityStore.clear()
        territoryStore.clear()
        FeedRepository.shared.clear()
        SocialService.shared.clear()
        
        authService.signOut()
    }
    
    func refreshGamification() {
        // In a real app, this might trigger a cloud function or re-fetch
        fetchProfileData()
    }
    
    // MARK: - Helpers
    private func refreshLocalStats() {
        self.streakWeeks = activityStore.calculateCurrentStreak()
        
        let cutoffDate = configService.cutoffDate()
        
        // Activities in configurable window
        self.activitiesCount = activityStore.activities.filter { $0.startDate >= cutoffDate }.count
        
        // Territories conquered in configurable window
        // Note: 'conqueredCells' contains current ownership. We check 'lastConqueredAt'.
        self.territoriesCount = territoryStore.conqueredCells.values.filter { $0.lastConqueredAt >= cutoffDate }.count
        
        // Total Cells Owned (Historical/Current Total)
        self.totalCellsConquered = territoryStore.conqueredCells.count
        
        // territoryInventory: Group by activityId
        let cells = territoryStore.conqueredCells.values
        let grouped = Dictionary(grouping: cells) { $0.activityId ?? "unknown" }
        
        var inventory: [TerritoryInventoryItem] = []
        for (activityId, groupCells) in grouped where activityId != "unknown" {
            let label = activityStore.activities.first { $0.id.uuidString == activityId }?.locationLabel ?? "Exploración"
            let expiry = groupCells.map { $0.expiresAt }.min() ?? Date()
            
            inventory.append(TerritoryInventoryItem(
                id: activityId,
                locationLabel: label,
                territories: groupCells,
                expiresAt: expiry
            ))
        }
        
        // Sort by expiry date (closer first) to remind user to defend
        self.territoryInventory = inventory.sorted { $0.expiresAt < $1.expiresAt }
        
        // Guardar agregados en Firestore (user document)
        if let userId = authService.userId {
            userRepository.updateTerritoryStats(
                userId: userId,
                totalOwned: totalCellsConquered,
                recentWindow: territoriesCount
            )
        }
    }
    
    private func updateWithUser(_ user: User) {
        self.userDisplayName = user.displayName ?? "Adventurer"
        if let urlString = user.avatarURL, let url = URL(string: urlString) {
            self.avatarURL = url
        }
        
        self.totalHistoricalConquered = user.totalConqueredTerritories ?? 0
        self.totalStolen = user.totalStolenTerritories ?? 0
        self.totalDefended = user.totalDefendedTerritories ?? 0
        self.totalRecaptured = user.totalRecapturedTerritories ?? 0
        
        self.recentTheftVictims = user.recentTheftVictims ?? []
        self.recentThieves = user.recentThieves ?? []
        
        // Sync GamificationService with fetched data
        // This will trigger the observers above to update the UI properties
        gamificationService.syncState(xp: user.xp, level: user.level)
    }
    
    // MARK: - Avatar Upload
    func uploadAvatar(imageData: Data) async {
        guard let userId = authService.userId else { return }
        #if canImport(FirebaseStorage)
        let storageRef = storage.reference().child("users/\(userId)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let url = try await storageRef.downloadURL()
            
            // Update Firestore user document
            let userRef = Firestore.shared.collection("users").document(userId)
            try await userRef.setData(["avatarURL": url.absoluteString], merge: true)
            
            await MainActor.run {
                self.avatarURL = url
                AvatarCacheManager.shared.save(data: imageData, for: userId)
                SocialService.shared.updateAvatar(for: userId, url: url, data: imageData)
            }
        } catch {
            print("Error uploading avatar: \(error)")
        }
        #else
        print("FirebaseStorage not available")
        #endif
    }
    
    // Procesamiento delegado al cropper; no reprocesar aquí
    private func processImageData(_ data: Data) -> Data? { nil }
}
