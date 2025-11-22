import Foundation
import CoreLocation

class TerritoryService {
    private let territoryStore: TerritoryStore
    
    init(territoryStore: TerritoryStore) {
        self.territoryStore = territoryStore
    }
    
    func processActivity(_ activity: ActivitySession) -> Int {
        var newCells: [TerritoryCell] = []
        var newConqueredCount = 0
        
        // Get all existing cells to check if we are refreshing or conquering new ones
        let existingCells = territoryStore.conqueredCells
        
        // Iterate through segments to interpolate and catch all cells
        guard !activity.route.isEmpty else { return 0 }
        
        // Add start point cell
        if let first = activity.route.first {
            let cell = existingCells[TerritoryGrid.cellId(x: TerritoryGrid.cellIndex(for: first.coordinate).x, y: TerritoryGrid.cellIndex(for: first.coordinate).y)] ?? TerritoryGrid.getCell(for: first.coordinate)
            processCell(cell, existingCells: existingCells, newCells: &newCells, newConqueredCount: &newConqueredCount, activity: activity)
        }
        
        // Process segments
        for i in 0..<activity.route.count - 1 {
            let start = activity.route[i].coordinate
            let end = activity.route[i+1].coordinate
            
            let interpolatedCells = TerritoryGrid.cellsBetween(start: start, end: end)
            
            for cellTemplate in interpolatedCells {
                // We need to check if we already have this cell in our existing store to preserve history
                // or if we already added it to newCells
                
                if newCells.contains(where: { $0.id == cellTemplate.id }) {
                    continue
                }
                
                let cell = existingCells[cellTemplate.id] ?? cellTemplate
                processCell(cell, existingCells: existingCells, newCells: &newCells, newConqueredCount: &newConqueredCount, activity: activity)
            }
        }
        
        territoryStore.upsertCells(newCells)
        
        // NEW: Multiplayer Integration
        // 1. Save to Firestore (Now saving Cells)
        if !newCells.isEmpty {
             // We save the individual cells
             let userId = AuthenticationService.shared.userId ?? "unknown_user"
             TerritoryRepository.shared.saveCells(newCells, userId: userId)
        }
        
        // 2. Award XP
        if newConqueredCount > 0 {
            for _ in 0..<newConqueredCount {
                GamificationService.shared.awardConquestXP()
            }
        }
        
        // 3. Post to Feed
        if newConqueredCount > 0 {
            let event = FeedEvent(
                id: nil,
                type: "conquest",
                message: "Conquered \(newConqueredCount) new territories!",
                userId: "current_user", // In real app, use Auth ID
                timestamp: Date()
            )
            FeedRepository.shared.postEvent(event)
        }
        
        return newConqueredCount
    }
    
    private func processCell(_ cell: TerritoryCell, existingCells: [String: TerritoryCell], newCells: inout [TerritoryCell], newConqueredCount: inout Int, activity: ActivitySession) {
        var mutableCell = cell
        let wasExpiredOrNew = mutableCell.isExpired || existingCells[mutableCell.id] == nil
        
        if wasExpiredOrNew {
            newConqueredCount += 1
        }
        
        mutableCell.lastConqueredAt = activity.endDate
        mutableCell.expiresAt = Calendar.current.date(byAdding: .day, value: TerritoryGrid.daysToExpire, to: activity.endDate)!
        
        newCells.append(mutableCell)
    }
    
    func recalculateExpiredCells() {
        territoryStore.removeExpiredCells(now: Date())
    }
}
