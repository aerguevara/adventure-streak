import Foundation
import CoreLocation

@MainActor
class TerritoryService {
    private let territoryStore: TerritoryStore
    
    init(territoryStore: TerritoryStore) {
        self.territoryStore = territoryStore
    }
    
    func processActivity(_ activity: ActivitySession) -> TerritoryStats {
        var newCells: [TerritoryCell] = []
        var newConqueredCount = 0
        var defendedCount = 0
        let recapturedCount = 0 // Logic for recapture would go here (checking previous owner)
        
        // Get all existing cells to check if we are refreshing or conquering new ones
        let existingCells = territoryStore.conqueredCells
        
        // Iterate through segments to interpolate and catch all cells
        guard !activity.route.isEmpty else { 
            return TerritoryStats(newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0)
        }
        
        // Add start point cell
        if let first = activity.route.first {
            let cell = existingCells[TerritoryGrid.cellId(x: TerritoryGrid.cellIndex(for: first.coordinate).x, y: TerritoryGrid.cellIndex(for: first.coordinate).y)] ?? TerritoryGrid.getCell(for: first.coordinate)
            processCell(cell, existingCells: existingCells, newCells: &newCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, activity: activity)
        }
        
        // Process segments
        for i in 0..<activity.route.count - 1 {
            let start = activity.route[i].coordinate
            let end = activity.route[i+1].coordinate
            
            let interpolatedCells = TerritoryGrid.cellsBetween(start: start, end: end)
            
            for cellTemplate in interpolatedCells {
                if newCells.contains(where: { $0.id == cellTemplate.id }) {
                    continue
                }
                
                let cell = existingCells[cellTemplate.id] ?? cellTemplate
                processCell(cell, existingCells: existingCells, newCells: &newCells, newConqueredCount: &newConqueredCount, defendedCount: &defendedCount, activity: activity)
            }
        }
        
        territoryStore.upsertCells(newCells)
        
        // NEW: Multiplayer Integration
        // 1. Save to Firestore (Now saving Cells)
        if !newCells.isEmpty {
             let userId = AuthenticationService.shared.userId ?? "unknown_user"
             TerritoryRepository.shared.saveCells(newCells, userId: userId)
        }
        
        // Note: XP and Feed are now handled by the caller (ViewModel) using GamificationService
        
        return TerritoryStats(
            newCellsCount: newConqueredCount,
            defendedCellsCount: defendedCount,
            recapturedCellsCount: recapturedCount
        )
    }
    
    private func processCell(_ cell: TerritoryCell, existingCells: [String: TerritoryCell], newCells: inout [TerritoryCell], newConqueredCount: inout Int, defendedCount: inout Int, activity: ActivitySession) {
        var mutableCell = cell
        let wasExpiredOrNew = mutableCell.isExpired || existingCells[mutableCell.id] == nil
        
        if wasExpiredOrNew {
            newConqueredCount += 1
        } else {
            defendedCount += 1
        }
        
        mutableCell.lastConqueredAt = activity.endDate
        mutableCell.expiresAt = Calendar.current.date(byAdding: .day, value: TerritoryGrid.daysToExpire, to: activity.endDate)!
        
        newCells.append(mutableCell)
    }
    
    func recalculateExpiredCells() {
        territoryStore.removeExpiredCells(now: Date())
    }
}
