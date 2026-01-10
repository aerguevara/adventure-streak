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
    @Published var isProfileLoaded: Bool = false
    
    var currentSeason: Season {
        SeasonManager.shared.getCurrentSeason()
    }
    @Published var isLoading: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var errorMessage: String? = nil
    
    // NEW: Competitive Stats
    @Published var joinedAt: Date? = nil
    @Published var bestWeeklyDistanceKm: Double = 0
    @Published var currentWeekDistanceKm: Double = 0
    @Published var totalDistanceKm: Double = 0
    @Published var totalDistanceNoGpsKm: Double = 0
    @Published var nextGoal: RankingEntry? = nil
    @Published var xpToNextGoal: Int? = nil
    
    // NEW: Separated Inventory Lists (Owned vs Vengeance)
    @Published var vengeanceItems: [TerritoryInventoryItem] = []
    
    // NEW: Active Rivalries
    @Published var activeRivalries: [RivalryRelationship] = []
    
    // NEW: High Value Targets (Ancient territories with loot)
    @Published var highValueTargets: [HighValueTargetItem] = []
    
    @Published var reservedIcons: Set<String> = []
    @Published var hasAcknowledgedDecReset: Bool = true // Legacy
    @Published var lastAcknowledgeSeasonId: String? = nil
    @Published var lastAcknowledgeResetDate: Date? = nil
    @Published var showSeasonResetModal: Bool = false
    
    private var currentUser: User? = nil
    private var lastAcknowledgmentTimestamp: Date? = nil
    
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
            
            return isHotSpot || isExpiringSoon || isRecentlyExpired
        }
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
    private let locationService: LocationService // NEW
    #if canImport(FirebaseStorage)
    private let storage = Storage.storage()
    #endif
    
    // MARK: - Init
    init(activityStore: ActivityStore, 
         territoryStore: TerritoryStore, 
         userRepository: UserRepository = .shared,
         authService: AuthenticationService = .shared,
         gamificationService: GamificationService = .shared,
         configService: GameConfigService,
         locationService: LocationService = .shared) { // NEW
        self.activityStore = activityStore
        self.territoryStore = territoryStore
        self.userRepository = userRepository
        self.authService = authService
        self.gamificationService = gamificationService
        self.configService = configService
        self.locationService = locationService // NEW
        
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
                if let _ = userId {
                    print("ProfileViewModel: userId found, fetching profile data...")
                    self?.fetchProfileData()
                } else {
                    print("ProfileViewModel: userId is nil, resetting state...")
                    self?.resetState()
                }
            }
            .store(in: &cancellables)
            
        // NEW: Observe location updates to trigger proactive treasure search
        locationService.$currentLocation
            .compactMap { $0?.coordinate }
            .first() // Only trigger proactive zone once per load/location acquisition
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinate in
                guard self?.authService.userId != nil else { return }
                print("ProfileViewModel: Location acquired, triggering proactive target search...")
                TerritoryRepository.shared.observeProactiveZone(around: coordinate)
            }
            .store(in: &cancellables)
 
        // NEW: Observe vengeance targets from repository
        TerritoryRepository.shared.$vengeanceTargets
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalStats()
            }
            .store(in: &cancellables)
            
        // NEW: Observe proactive territories (stableNearby treasures)
        TerritoryRepository.shared.$proactiveTerritories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalStats()
            }
            .store(in: &cancellables)
            
        // NEW: Observe SeasonManager for season changes & reset status
        SeasonManager.shared.$currentSeason
            .combineLatest(SeasonManager.shared.$isResetAcknowledgmentPending)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateSeasonModalStatus()
            }
            .store(in: &cancellables)
    }
    
    private var lastUserUID: String = ""
    private var lastUserXP: Int = -1
    private var lastUserLevel: Int = -1
    private var lastUserName: String = "" // NEW: Track last name to detect changes
    
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
        
        _ = userRepository.observeUser(userId: userId) { [weak self] user in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                if let user = user {
                    // DEDUPLICATION: Only update if it's a new user, stats changed, OR NAME CHANGED
                    if self.lastUserUID != user.id || 
                       self.lastUserXP != user.xp || 
                       self.lastUserLevel != user.level ||
                       self.lastUserName != user.displayName {
                        
                        self.lastUserUID = user.id ?? ""
                        self.lastUserXP = user.xp
                        self.lastUserLevel = user.level
                        self.lastUserName = user.displayName ?? ""
                        
                        self.updateWithUser(user)
                        
                        // DEPRECATED: We no longer sync the entire inventory on every update.
                        // if let userId = user.id {
                        //     await TerritoryRepository.shared.syncUserTerritories(userId: userId, store: self.territoryStore)
                        // }
                    }
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
        
        // Reset local UI state immediately to prevent flicker
        resetState()
        
        authService.signOut()
    }
    
    private func resetState() {
        self.userDisplayName = "Aventurero"
        self.avatarURL = nil
        self.level = 1
        self.totalXP = 0
        self.nextLevelXP = 1000
        self.xpProgress = 0.0
        self.territoriesCount = 0
        self.activitiesCount = 0
        self.totalCellsConquered = 0
        self.streakWeeks = 0
        self.mapIcon = nil
        self.recentTheftVictims = []
        self.recentThieves = []
        self.vengeanceItems = []
        self.territoryInventory = []
        self.activeRivalries = []
        self.highValueTargets = []
        self.lastUserUID = ""
        self.lastUserXP = -1
        self.lastUserLevel = -1
        self.lastUserName = "" // NEW
        self.lastAcknowledgeSeasonId = nil
        self.isProfileLoaded = false
        self.showSeasonResetModal = false
    }
    
    func refreshGamification() {
        // In a real app, this might trigger a cloud function or re-fetch
        fetchProfileData()
    }
    
    // MARK: - Helpers
    private func refreshLocalStats() {
        // self.streakWeeks = activityStore.calculateCurrentStreak() // DEPRECATED: Rely on server stats from user object
        
        // Activities (Total Historical)
        self.activitiesCount = activityStore.activities.count
        
        // self.territoriesCount = territoryStore.conqueredCells.count // DEPRECATED: Rely on server stats from user object
        
        // Total Cells Owned (Historical/Current Total) - DEPRECATED: Rely on server stats from user object
        // self.totalCellsConquered = territoryStore.conqueredCells.count
        
        // territoryInventory: Group by activityId
        let cells = territoryStore.conqueredCells.values
        let grouped = Dictionary(grouping: cells) { $0.activityId ?? "unknown" }
        
        // OPTIMIZATION: Index activities for O(1) lookup during grouping
        let activitiesMap = Dictionary(uniqueKeysWithValues: activityStore.activities.map { ($0.id.uuidString, $0) })
        
        var inventory: [TerritoryInventoryItem] = []
        for (activityId, groupCells) in grouped where activityId != "unknown" {
            let activity = activitiesMap[activityId] // Fast lookup!
            let cellLabel = groupCells.first?.locationLabel
            
            let label = activity?.locationLabel ?? cellLabel ?? "Exploración"
            let expiry = groupCells.map { $0.expiresAt }.min() ?? Date()
            
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
        
        // NO WRITES TO FIRESTORE HERE.
        // The backend computes stats during activity processing.
        // The app now relies on pre-aggregated stats in the User object.
        
        // Calculate Active Rivalries
        self.activeRivalries = calculateActiveRivalries()
        
        // Calculate High Value Targets
        self.highValueTargets = calculateHighValueTargets()
    }
    
    private func calculateHighValueTargets() -> [HighValueTargetItem] {
        let repo = TerritoryRepository.shared
        let now = Date()
        let currentUserId = authService.userId ?? ""
        
        // Filter: Rivals from PROACTIVE pool (stable)
        let ancientRivals = repo.proactiveTerritories.filter { territory in
            // Use firstConqueredAt if available, fallback to activityEndAt
            let referenceDate = territory.firstConqueredAt ?? territory.activityEndAt
            
            guard territory.userId != currentUserId else { return false }
            
            let ageInSeconds = now.timeIntervalSince(referenceDate)
            return ageInSeconds > 15 * 24 * 3600 // Threshold: 15 days
        }
        
        // Map to HighValueTargetItem
        var items: [HighValueTargetItem] = ancientRivals.compactMap { territory in
            guard let id = territory.id else { return nil }
            
            let referenceDate = territory.firstConqueredAt ?? territory.activityEndAt
            let ageInDays = Int(now.timeIntervalSince(referenceDate) / (24 * 3600))
            let lootXP = ageInDays * 2 // Default factor
            
            return HighValueTargetItem(
                id: id,
                ownerId: territory.userId,
                ownerName: "Rival", // Names are fetched asynchronously on map, using Rival as fallback
                ownerIcon: MapIconCacheManager.shared.getIcon(for: territory.userId),
                ownerAvatarURL: nil, // Will be loaded by the card itself
                locationLabel: territory.locationLabel ?? "Territorio Desconocido",
                lootXP: lootXP,
                ageInDays: ageInDays,
                territories: [TerritoryCell(
                    id: id,
                    centerLatitude: territory.centerLatitude,
                    centerLongitude: territory.centerLongitude,
                    boundary: territory.boundary,
                    lastConqueredAt: territory.activityEndAt,
                    expiresAt: territory.expiresAt,
                    ownerUserId: territory.userId,
                    ownerDisplayName: nil,
                    ownerUploadedAt: territory.uploadedAt?.dateValue(),
                    activityId: territory.activityId,
                    firstConqueredAt: territory.firstConqueredAt,
                    defenseCount: territory.defenseCount,
                    isHotSpot: territory.isHotSpot,
                    locationLabel: territory.locationLabel
                )]
            )
        }
        
        // Sort by loot value (descending)
        items.sort { $0.lootXP > $1.lootXP }
        
        return Array(items.prefix(10)) // Show top 10
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
        } else {
            self.avatarURL = nil
        }
        
        self.totalHistoricalConquered = user.totalConqueredTerritories ?? 0
        self.totalStolen = user.totalStolenTerritories ?? 0
        self.totalDefended = user.totalDefendedTerritories ?? 0
        self.totalRecaptured = user.totalRecapturedTerritories ?? 0
        
        // NEW: Assign counts directly from server-side computed fields
        self.activitiesCount = user.totalActivities ?? 0
        self.territoriesCount = user.totalCellsOwned ?? 0
        self.totalCellsConquered = user.totalCellsOwned ?? 0
        self.streakWeeks = user.currentStreakWeeks ?? 0
        
        self.recentTheftVictims = user.recentTheftVictims ?? []
        self.recentThieves = user.recentThieves ?? []
        
        self.joinedAt = user.joinedAt
        self.bestWeeklyDistanceKm = user.bestWeeklyDistanceKm ?? 0
        self.currentWeekDistanceKm = user.currentWeekDistanceKm ?? 0
        self.totalDistanceKm = user.totalDistanceKm ?? 0
        self.totalDistanceNoGpsKm = user.totalDistanceNoGpsKm ?? 0
        
        self.mapIcon = user.mapIcon
        if let icon = user.mapIcon, let userId = user.id {
            MapIconCacheManager.shared.setIcon(icon, for: userId)
        }
        
        // NEW: Start observing vengeance targets
        if let userId = user.id {
            print("DEBUG: [ProfileViewModel] updateWithUser calling observeVengeanceTargets for \(userId)")
            TerritoryRepository.shared.observeVengeanceTargets(userId: userId)
            
            // Determine next goal
            Task {
                await self.calculateNextGoal(for: userId)
            }
        } else {
            print("ERROR: [ProfileViewModel] updateWithUser user.id is NIL. Cannot observe vengeance.")
        }
        
        // Sync GamificationService with fetched data
        // This will trigger the observers above to update the UI properties
        gamificationService.syncState(xp: user.xp, level: user.level)
        
        let isResetAcknowledged = user.hasAcknowledgedDecReset ?? true
        print("DEBUG: ProfileViewModel: hasAcknowledgedDecReset is \(isResetAcknowledged). Show modal: \(!isResetAcknowledged)")
        self.hasAcknowledgedDecReset = isResetAcknowledged
        
        // SHIELD: Only ignore server data if we JUST acknowledged locally in the last 30 seconds.
        // This prevents the "stale read" flicker (where Firestore returns old data before the write)
        // without blocking intentional manual server resets (which would happen outside this window).
        let isRecentlyAcknowledged = lastAcknowledgmentTimestamp.map { Date().timeIntervalSince($0) < 30 } ?? false
        
        if isRecentlyAcknowledged {
            print("🛡️ [ProfileViewModel] Acknowledgment shield ACTIVE. Keeping current local state.")
        } else {
            self.lastAcknowledgeSeasonId = user.lastAcknowledgeSeasonId
            self.lastAcknowledgeResetDate = user.lastSeasonReset
            
            // Sync UserDefaults to keep track across launches
            if let seasonId = user.lastAcknowledgeSeasonId {
                UserDefaults.standard.set(seasonId, forKey: "lastAcknowledgeSeasonId")
            }
            if let resetDate = user.lastSeasonReset {
                UserDefaults.standard.set(resetDate.timeIntervalSince1970, forKey: "lastAcknowledgeResetDate")
            } else {
                // If server says no reset date, clear local record
                UserDefaults.standard.removeObject(forKey: "lastAcknowledgeResetDate")
            }
        }
        
        self.currentUser = user
        self.isProfileLoaded = true
        self.updateSeasonModalStatus()
        
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
            
            // Versioning: Append timestamp to bypass caches
            let versionedURLString = "\(url.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
            
            // Update Firestore user document
            let userRef = Firestore.shared.collection("users").document(userId)
            try await userRef.setData(["avatarURL": versionedURLString], merge: true)
            
            await MainActor.run {
                if let versionedURL = URL(string: versionedURLString) {
                    self.avatarURL = versionedURL
                    AuthenticationService.shared.userAvatarURL = versionedURLString
                }
                AvatarCacheManager.shared.clear(for: userId)
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
    
    func acknowledgeSeason(_ seasonId: String) async {
        guard let userId = authService.userId else { return }
        do {
            let serverResetDate = self.currentUser?.lastSeasonReset ?? Date()
            let configResetDate = GameConfigService.shared.config.globalResetDate ?? Date()
            let safetyFloor = max(serverResetDate, configResetDate)
            
            // 0. Update server acknowledgment (IMPORTANT: Pass resetDate to avoid repeated popups)
            try await userRepository.acknowledgeSeason(userId: userId, seasonId: seasonId, resetDate: serverResetDate)
            
            // NEW: Use a stricter safety floor. 
            
            print("🛡️ [ProfileViewModel] Setting new onboarding safety floor to \(safetyFloor)")
            UserDefaults.standard.set(safetyFloor.timeIntervalSince1970, forKey: "onboardingCompletionDate")
            
            // Clear all local caches to ensure a completely clean state after reset
            ActivityStore.shared.clear()
            TerritoryStore.shared.clear()
            FeedRepository.shared.clear()
            SocialService.shared.clear()
            PendingRouteStore.shared.clear()
            
            // 1. Update local acknowledgment state synchronously to avoid flicker
            self.lastAcknowledgeSeasonId = seasonId
            if let resetDate = self.currentUser?.lastSeasonReset {
                self.lastAcknowledgeResetDate = resetDate
                UserDefaults.standard.set(resetDate.timeIntervalSince1970, forKey: "lastAcknowledgeResetDate")
            }
            UserDefaults.standard.set(seasonId, forKey: "lastAcknowledgeSeasonId")
            
            self.showSeasonResetModal = false
            SeasonManager.shared.isResetAcknowledgmentPending = false
            self.hasAcknowledgedDecReset = true
            self.lastAcknowledgmentTimestamp = Date()
            
            // 2. Recargar perfil del usuario (esto desencadenará actualizaciones reactivas, 
            // pero ya tenemos las banderas locales actualizadas para el modal).
            authService.refreshUserProfile(userId: userId)
            
            // 3. NOTIFICATION: Tell WorkoutsViewModel to re-import immediately (HK + Remote)
            NotificationCenter.default.post(name: NSNotification.Name("TriggerImmediateImport"), object: nil)
        } catch {
            print("Error acknowledging season: \(error)")
        }
    }
    
    // Procesamiento delegado al cropper; no reprocesar aquí
    private func processImageData(_ data: Data) -> Data? { nil }
    
    // MARK: - Competitive Logic
    private func calculateNextGoal(for userId: String) async {
        GamificationRepository.shared.fetchWeeklyRanking(limit: 50) { [weak self] entries in
            guard let self = self else { return }
            Task { @MainActor in
                // Find user's position
                if let userIndex = entries.firstIndex(where: { $0.userId == userId }) {
                    if userIndex > 0 {
                        let target = entries[userIndex - 1]
                        self.nextGoal = target
                        self.xpToNextGoal = max(target.weeklyXP - entries[userIndex].weeklyXP, 0)
                    } else {
                        self.nextGoal = nil // User is #1
                        self.xpToNextGoal = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Season Modal Logic
    private func updateSeasonModalStatus() {
        guard authService.userId != nil else {
            self.showSeasonResetModal = false
            return
        }
        
        // Now delegating to SeasonManager but we keep showSeasonResetModal for the UI
        self.showSeasonResetModal = SeasonManager.shared.isResetAcknowledgmentPending
        
        print("DEBUG: ProfileViewModel: updateSeasonModalStatus. Result: \(showSeasonResetModal)")
    }
    
    func deleteAccount() async {
        isDeletingAccount = true
        errorMessage = nil
        
        do {
            try await authService.deleteAccount()
            await MainActor.run {
                isDeletingAccount = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error al borrar la cuenta: \(error.localizedDescription)"
                isDeletingAccount = false
            }
        }
    }
}
