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

// NEW: Struct for vengeance details
struct ThieveryData {
    let thiefId: String
    let thiefName: String
    let stolenAt: Date
}

struct TerritoryInventoryItem: Identifiable {
    let id: String // activityId or "vengeance_" + cellId
    let locationLabel: String
    let territories: [TerritoryCell]
    let expiresAt: Date
    var isVengeance: Bool = false
    var thieveryData: ThieveryData? = nil
    
    init(id: String, locationLabel: String, territories: [TerritoryCell], expiresAt: Date, isVengeance: Bool = false, thieveryData: ThieveryData? = nil) {
        self.id = id
        self.locationLabel = locationLabel
        self.territories = territories
        self.expiresAt = expiresAt
        self.isVengeance = isVengeance
        self.thieveryData = thieveryData
    }
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
    @Published var mapIcon: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // NEW: Separated Inventory Lists (Owned vs Vengeance)
    @Published var vengeanceItems: [TerritoryInventoryItem] = []
    
    // NEW: Active Rivalries
    @Published var activeRivalries: [RivalryRelationship] = []
    
    @Published var reservedIcons: Set<String> = []
    @Published var hasAcknowledgedDecReset: Bool = true // Default to true to avoid modal flicker
    
    // Rivals
    @Published var recentTheftVictims: [Rival] = []
    @Published var recentThieves: [Rival] = []
    
    private var lastSentTotalOwned: Int?
    private var lastSentRecentCount: Int?
    
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
    
    var vulnerableTerritories: [TerritoryInventoryItem] {
        // Combine vengeance items (high priority) with expiring/expired territories
        let now = Date()
        let warningThreshold = now.addingTimeInterval(24 * 3600) // Expires in < 24 hours
        let gracePeriodThreshold = now.addingTimeInterval(-24 * 3600) // Expired < 24 hours ago
        
        let vulnerable = territoryInventory.filter { item in
            // 1. Hot Spot?
            let isHotSpot = item.territories.contains { $0.isHotSpot == true }
            // 2. Está a punto de expirar? (Futuro cercano)
            let isExpiringSoon = item.expiresAt < warningThreshold && item.expiresAt > now
            // 3. Ya expiró pero está en periodo de gracia? (Pasado reciente)
            let isRecentlyExpired = item.expiresAt <= now && item.expiresAt > gracePeriodThreshold
            
            print("DEBUG: Checking item \(item.id) - HotSpot: \(isHotSpot) (flag: \(item.territories.first?.isHotSpot)), Soon: \(isExpiringSoon) (exp: \(item.expiresAt)), Grace: \(isRecentlyExpired)")
            
            return isHotSpot || isExpiringSoon || isRecentlyExpired
        }
        print("DEBUG: Vulnerable count: \(vulnerable.count). Vengeance count: \(vengeanceItems.count)")
        return vengeanceItems + vulnerable
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
            
        // NEW: Observe vengeance targets from repository
        TerritoryRepository.shared.$vengeanceTargets
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalStats()
            }
            .store(in: &cancellables)
            
        // NEW: Observe vengeance details (async fetch results)
        TerritoryRepository.shared.$vengeanceTerritoryDetails
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalStats()
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
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                if let user = user {
                    print("DEBUG: ProfileViewModel: Received user update (hasAcknowledgedDecReset: \(user.hasAcknowledgedDecReset ?? true))")
                    self.updateWithUser(user)
                    // Ensure local territory store is in sync with Firestore (vital for expiration updates)
                    if let userId = user.id {
                        await TerritoryRepository.shared.syncUserTerritories(userId: userId, store: self.territoryStore)
                    }
                } else {
                    print("DEBUG: ProfileViewModel: Could not fetch user profile or user is nil for ID: \(userId)")
                }
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
        
        // Activities (Total Historical)
        self.activitiesCount = activityStore.activities.count
        
        // Territories conquered (Total Historical Ownership)
        // Note: 'conqueredCells' contains current ownership.
        self.territoriesCount = territoryStore.conqueredCells.count
        
        // Total Cells Owned (Historical/Current Total) - Keep as is for now
        self.totalCellsConquered = territoryStore.conqueredCells.count
        
        // territoryInventory: Group by activityId
        let cells = territoryStore.conqueredCells.values
        let grouped = Dictionary(grouping: cells) { $0.activityId ?? "unknown" }
        
        var inventory: [TerritoryInventoryItem] = []
        print("DEBUG: [ProfileViewModel] Refreshing items. Activities in store: \(activityStore.activities.count)")
        for (activityId, groupCells) in grouped where activityId != "unknown" {
            let activity = activityStore.activities.first { $0.id.uuidString == activityId }
            let cellLabel = groupCells.first?.locationLabel
            
            // Priority: 1. Real activity label, 2. Cell's own label (from script), 3. Catch-all
            let label = activity?.locationLabel ?? cellLabel ?? "Exploración"
            let expiry = groupCells.map { $0.expiresAt }.min() ?? Date()
            
            print("DEBUG: [ProfileViewModel] activityId: \(activityId) -> activityFound: \(activity != nil), cellLabel: \(cellLabel ?? "NIL"), FINAL: \(label)")
            
            inventory.append(TerritoryInventoryItem(
                id: activityId,
                locationLabel: label,
                territories: groupCells,
                expiresAt: expiry
            ))
        }

        // Vengeance items logic (Grouped by ActivityId)
        var vItems: [TerritoryInventoryItem] = []
        
        // Group by activityId (or cellId if missing)
        let vengeanceGroups = Dictionary(grouping: TerritoryRepository.shared.vengeanceTargets) { target in
            target.activityId ?? target.cellId
        }
        
        for (groupId, targets) in vengeanceGroups {
            var combinedCells: [TerritoryCell] = []
            var locationLabel = "¡RECLAMA TU HONOR!"
            var minExpiry = Date.distantFuture
            var thiefId = "" // NEW
            var thiefName = ""
            var stolenAt = Date()
            
            // Collect cells for this group
            for target in targets {
                // Determine label (use first available)
                if let label = target.locationLabel, locationLabel == "¡RECLAMA TU HONOR!" {
                    locationLabel = label
                }
                
                // Metadata common to group (take from first)
                if thiefName.isEmpty {
                    thiefId = target.thiefId // NEW
                    thiefName = target.thiefName
                    stolenAt = target.stolenAt
                }
                
                // Find cell details
                var matchedCell: TerritoryCell? = territoryStore.conqueredCells[target.cellId]
                
                if matchedCell == nil {
                    // Search in remote caches
                    let repo = TerritoryRepository.shared
                    if let remote = repo.otherTerritories.first(where: { $0.id == target.cellId }) ??
                                    repo.vengeanceTerritoryDetails.first(where: { $0.id == target.cellId }) {
                        matchedCell = TerritoryCell(
                            id: remote.id ?? target.cellId,
                            centerLatitude: remote.centerLatitude,
                            centerLongitude: remote.centerLongitude,
                            boundary: remote.boundary,
                            lastConqueredAt: remote.activityEndAt,
                            expiresAt: remote.expiresAt,
                            ownerUserId: remote.userId,
                            ownerDisplayName: nil,
                            ownerUploadedAt: remote.uploadedAt?.dateValue(),
                            activityId: remote.activityId,
                            isHotSpot: remote.isHotSpot,
                            locationLabel: remote.locationLabel
                        )
                    }
                }
                
                if let cell = matchedCell {
                    combinedCells.append(cell)
                    if cell.expiresAt < minExpiry {
                        minExpiry = cell.expiresAt
                    }
                }
            }
            
            if !combinedCells.isEmpty {
                vItems.append(TerritoryInventoryItem(
                    id: "vengeance_group_\(groupId)",
                    locationLabel: locationLabel,
                    territories: combinedCells,
                    expiresAt: minExpiry,
                    isVengeance: true,
                    thieveryData: ThieveryData(thiefId: thiefId, thiefName: thiefName, stolenAt: stolenAt) // Updated
                ))
            }
        }

        // Sort by stolenAt (most recent first) to avoid flasheo and have a logical order
        self.vengeanceItems = vItems.sorted { ($0.thieveryData?.stolenAt ?? Date.distantPast) > ($1.thieveryData?.stolenAt ?? Date.distantPast) }
        
        // Sort by expiry date (closer first) to remind user to defend
        self.territoryInventory = inventory.sorted { $0.expiresAt < $1.expiresAt }
        
        // Guardar agregados en Firestore (user document)
        if let userId = authService.userId {
            let currentTotal = totalCellsConquered
            let currentRecent = territoriesCount
            
            // BREAK LOOP: Only write if values have actually changed
            if currentTotal != lastSentTotalOwned || currentRecent != lastSentRecentCount {
                print("📤 ProfileViewModel: Syncing stats to Firestore (\(currentTotal) total, \(currentRecent) recent). Previous: (\(lastSentTotalOwned ?? -1), \(lastSentRecentCount ?? -1))")
                lastSentTotalOwned = currentTotal
                lastSentRecentCount = currentRecent
                
                userRepository.updateTerritoryStats(
                    userId: userId,
                    totalOwned: currentTotal,
                    recentWindow: currentRecent
                )
            } else {
                // print("😴 ProfileViewModel: Stats unchanged, skipping Firestore write.")
            }
        }
        
        // Calculate Active Rivalries
        self.activeRivalries = calculateActiveRivalries()
    }
    
    private func calculateActiveRivalries() -> [RivalryRelationship] {
        var rivalsMap: [String: (String, String?, Int, Int, Date)] = [:] // userId -> (name, avatar, userScore, rivalScore, lastDate)
        
        // Process Thieves (They scored against me)
        for rival in recentThieves {
            rivalsMap[rival.userId] = (
                rival.displayName,
                rival.avatarURL,
                0, // userScore (initial)
                rival.count, // rivalScore
                rival.lastInteractionAt
            )
        }
        
        // Process Victims (I scored against them)
        for rival in recentTheftVictims {
            if let existing = rivalsMap[rival.userId] {
                // Update existing
                let newDate = rival.lastInteractionAt > existing.4 ? rival.lastInteractionAt : existing.4
                rivalsMap[rival.userId] = (
                    existing.0,
                    existing.1,
                    rival.count, // Set userScore
                    existing.3,
                    newDate
                )
            } else {
                // Add new
                rivalsMap[rival.userId] = (
                    rival.displayName,
                    rival.avatarURL,
                    rival.count, // userScore
                    0, // rivalScore
                    rival.lastInteractionAt
                )
            }
        }
        
        return rivalsMap.compactMap { (userId, data) -> RivalryRelationship? in
            let (name, avatar, userScore, rivalScore, date) = data
            // Determine trend (simplified logic)
            let trend: RankingTrend = userScore > rivalScore ? .up : (userScore < rivalScore ? .down : .neutral)
            
            return RivalryRelationship(
                userId: userId,
                displayName: name,
                avatarURL: avatar,
                userScore: userScore,
                rivalScore: rivalScore,
                lastInteractionAt: date,
                trend: trend
            )
        }.sorted { $0.lastInteractionAt > $1.lastInteractionAt }
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
        self.mapIcon = user.mapIcon
        if let icon = user.mapIcon, let userId = user.id {
            MapIconCacheManager.shared.setIcon(icon, for: userId)
        }
        
        // NEW: Start observing vengeance targets
        if let userId = user.id {
            print("DEBUG: [ProfileViewModel] updateWithUser calling observeVengeanceTargets for \(userId)")
            TerritoryRepository.shared.observeVengeanceTargets(userId: userId)
        } else {
            print("ERROR: [ProfileViewModel] updateWithUser user.id is NIL. Cannot observe vengeance.")
        }
        
        // Sync GamificationService with fetched data
        // This will trigger the observers above to update the UI properties
        gamificationService.syncState(xp: user.xp, level: user.level)
        
        let isResetAcknowledged = user.hasAcknowledgedDecReset ?? true
        print("DEBUG: ProfileViewModel: hasAcknowledgedDecReset is \(isResetAcknowledged). Show modal: \(!isResetAcknowledged)")
        self.hasAcknowledgedDecReset = isResetAcknowledged
        
        // No proactive purge needed here anymore; ActivityStore.reconcile is now aggressive
        // and will automatically remove local activities if they are missing from the server.
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
    
    // MARK: - Map Icon Management
    
    func fetchReservedIcons() async {
        let icons = await userRepository.fetchReservedIcons()
        await MainActor.run {
            self.reservedIcons = icons
        }
    }
    
    func updateMapIcon(_ icon: String) async {
        guard let userId = authService.userId else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            try await userRepository.updateUserMapIcon(userId: userId, icon: icon)
            await MainActor.run {
                self.mapIcon = icon
                MapIconCacheManager.shared.setIcon(icon, for: userId)
                AuthenticationService.shared.userMapIcon = icon
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func acknowledgeDecReset() async {
        guard let userId = authService.userId else { return }
        do {
            try await userRepository.acknowledgeDecReset(userId: userId)
            
            // Set onboarding date to the global reset date (or now as fallback)
            // to allow re-importing workouts that happened during this "new era".
            let safetyFloor = GameConfigService.shared.config.globalResetDate ?? Date()
            UserDefaults.standard.set(safetyFloor.timeIntervalSince1970, forKey: "onboardingCompletionDate")
            
            // Clear all local caches to ensure a completely clean state after reset
            ActivityStore.shared.clear()
            TerritoryStore.shared.clear()
            FeedRepository.shared.clear()
            SocialService.shared.clear()
            PendingRouteStore.shared.clear()
            
            // Recargar perfil del usuario inmediatamente (para refrescar XP/Nivel)
            authService.refreshUserProfile(userId: userId)
            
            await MainActor.run {
                self.hasAcknowledgedDecReset = true
                
                // NOTIFICATION: Tell WorkoutsViewModel to re-import immediately (HK + Remote)
                NotificationCenter.default.post(name: NSNotification.Name("TriggerImmediateImport"), object: nil)
            }
        } catch {
            print("Error acknowledging reset: \(error)")
        }
    }
    
    // Procesamiento delegado al cropper; no reprocesar aquí
    private func processImageData(_ data: Data) -> Data? { nil }
}
