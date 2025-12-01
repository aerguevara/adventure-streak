# Adventure Streak - Game System Implementation

## 🎮 Overview

This document describes the complete game logic system implemented for Adventure Streak, a fitness + territorial conquest app.

## 📋 System Architecture

### Core Components

#### 1. **MissionEngine** (`Services/MissionEngine.swift`)
Analyzes completed activities and classifies them into missions based on achievements.

**Mission Types:**
- **Territorial**: Based on new cells conquered (Common → Legendary)
- **Recapture**: Epic missions for recovering lost territory
- **Streak**: Progression missions for maintaining weekly streaks
- **Weekly Record**: Epic/Legendary for breaking distance records
- **Physical Effort**: High-intensity workout recognition

**Rarity Levels:**
- Common: 1-4 new cells
- Rare: 5-14 new cells
- Epic: 15-19 new cells or recaptures
- Legendary: 20+ new cells or major records

#### 2. **GameEngine** (`Services/GameEngine.swift`)
Main orchestrator that processes completed activities through the entire game system.

**Processing Flow:**
1. Save activity to store
2. Get XP context (current stats, streaks, records)
3. Calculate territorial delta (new/defended/recaptured cells)
4. Classify missions
5. Calculate XP breakdown
6. Update user gamification state
7. Create feed events
8. Notify UI observers

#### 3. **GamificationService** (`Services/GamificationService.swift`)
Calculates and applies XP based on activity performance.

**XP Sources:**
- **Base XP**: Distance × activity type factor (Run: 1.2x, Walk: 0.9x, Bike: 0.7x)
- **Territory XP**: New cells (8 XP), Defended (3 XP), Recaptured (12 XP)
- **Streak Bonus**: 10 XP × streak weeks
- **Weekly Record**: 30 XP base + 5 XP per km improvement
- **Badges**: Variable (future implementation)

**Level System:**
- Level = 1 + (Total XP / 1000)
- Each level requires 1000 XP

#### 4. **TerritoryService** (`Services/TerritoryService.swift`)
Manages territorial conquest mechanics.

**Territory Rules:**
- Cells expire after 7 days
- Revisiting expired cells = new conquest
- Revisiting active cells = defense (renews expiration)

#### 5. **FeedRepository** (`Services/FeedRepository.swift`)
Creates and manages activity feed events.

**Event Types:**
- Mission completed
- Territory conquered
- Level up
- Streak maintained
- Badge unlocked

## 🔧 Integration Points

### ViewModels

#### MapViewModel
- **Integration**: `stopActivity()` calls `GameEngine.completeActivity()`
- **Purpose**: Process real-time activities through game system

#### ProfileViewModel
- **Integration**: Observes `GamificationService` for XP/Level updates
- **Purpose**: Display current game state (Level, XP, Streak)

#### WorkoutsViewModel
- **Integration**: Displays activities with XP breakdowns
- **Purpose**: Show historical workout data with gamification

#### FeedViewModel
- **Integration**: Fetches events from `FeedRepository`
- **Purpose**: Display activity feed with missions and achievements

#### RankingViewModel
- **Integration**: Fetches weekly ranking from `GamificationRepository`
- **Purpose**: Display competitive leaderboard

## 📊 Data Models

### Mission
```swift
struct Mission {
    let id: String
    let userId: String
    let category: MissionCategory // territorial, physicalEffort, progression
    let name: String
    let description: String
    let rarity: MissionRarity // common, rare, epic, legendary
    var territorialDelta: TerritorialDelta?
    var xpBreakdown: XPBreakdown?
}
```

### XPBreakdown
```swift
struct XPBreakdown {
    let xpBase: Int
    let xpTerritory: Int
    let xpStreak: Int
    let xpWeeklyRecord: Int
    let xpBadges: Int
    var total: Int { ... }
}
```

### TerritorialDelta (alias for TerritoryStats)
```swift
struct TerritoryStats {
    let newCellsCount: Int
    let defendedCellsCount: Int
    let recapturedCellsCount: Int
}
```

## 🧪 Testing

### Manual Verification Steps

1. **Complete an Activity**
   - Start tracking in MapView
   - Move around to conquer territory
   - Stop activity
   - Verify: Activity appears in Workouts with XP
   - Verify: Feed shows mission event
   - Verify: Profile shows updated XP/Level

2. **Check Territory Mechanics**
   - Complete activity in new area → Should show "new cells"
   - Complete activity in same area within 7 days → Should show "defended"
   - Wait 7 days, revisit → Should show "new cells" again

3. **Verify Streak System**
   - Complete activities on consecutive weeks
   - Check Profile for streak count
   - Verify streak bonus in XP breakdown

4. **Test Ranking**
   - Navigate to Ranking tab
   - Verify current user is highlighted
   - Verify ranking updates after earning XP

## 🎯 Game Balance Configuration

Located in `XPModels.swift`:

```swift
enum XPConfig {
    static let minDistanceKm: Double = 0.5
    static let minDurationSeconds: Double = 5 * 60
    
    static let baseFactorPerKm: Double = 10.0
    static let factorRun: Double = 1.2
    static let factorBike: Double = 0.7
    static let factorWalk: Double = 0.9
    
    static let xpPerNewCell: Int = 8
    static let xpPerDefendedCell: Int = 3
    static let xpPerRecapturedCell: Int = 12
    
    static let baseStreakXPPerWeek: Int = 10
    static let weeklyRecordBaseXP: Int = 30
    static let legendaryThresholdCells: Int = 20
}
```

## 🚀 Future Enhancements

- [ ] Badge system implementation
- [ ] Buff system (temporary XP multipliers)
- [ ] Social features (friend challenges)
- [ ] Territory ownership conflicts (PvP)
- [ ] Weekly XP reset for ranking
- [ ] Achievement system
- [ ] Seasonal events

## 📝 Notes

- All game logic is marked with `// IMPLEMENTATION: ADVENTURE STREAK GAME SYSTEM`
- The system is designed to be extensible for future features
- Firebase integration is optional (works with local storage)
- UI never directly accesses domain models (uses ViewData structs)
