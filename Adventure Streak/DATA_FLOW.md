# Adventure Streak Data Flow Architecture

This document outlines how data is collected, processed, stored locally, and synced with Firebase.

## 1. Data Collection (HealthKit)
**Source**: Apple Health (Watch/iPhone)
**Trigger**: Automatic background import or manual refresh in History.

1.  **Fetch**: `HealthKitManager` queries `HKWorkout` (Outdoor Run/Walk/Cycle).
2.  **Route Extraction**: For each workout, `HKWorkoutRouteQuery` fetches GPS coordinates.
3.  **Processing**:
    *   Workouts are converted to `ActivitySession` objects.
    *   **Optimization**: Processing happens sequentially in a background queue (`.utility`) to prevent memory spikes.

## 2. Local Storage (The "Source of Truth" for the User)
Data is primarily stored locally on the device to ensure the app works offline and is fast.

### A. Activity History (`activities.json`)
*   **Content**: List of all completed `ActivitySession`s (Date, Distance, Duration, Route Coordinates).
*   **Storage**: JSON file in the App Sandbox.
*   **Manager**: `ActivityStore.swift`.
*   **Memory**: Loads all activities into RAM (Potential bottleneck if thousands of activities).

### B. Territories (`territories.json`)
*   **Content**: The grid of "conquered" cells.
    *   `id`: Unique Grid Index (e.g., "x:123,y:456").
    *   `coordinates`: The 4 corners of the cell.
    *   `status`: Conquered, Defended, Expired.
*   **Storage**: JSON file in the App Sandbox.
*   **Manager**: `TerritoryStore.swift`.
*   **Optimization**:
    *   Loading: Background thread.
    *   Saving: Background thread.
    *   **Current Issue**: Rendering thousands of these cells on the Map can freeze the UI.

## 3. Remote Storage (Firebase Firestore)
Used for Multiplayer features (seeing other players) and Backup.

### A. User Profile (`users/{userId}`)
*   **Content**: `displayName`, `xp`, `level`, `currentStreak`.
*   **Sync**: Updated whenever an activity is imported/completed.

### B. Global Territories (`territory_cells/{cellId}`)
*   **Content**: Represents the *current owner* of a specific cell.
    *   `ownerId`: ID of the user who owns it.
    *   `conqueredAt`: Timestamp.
    *   `center`: Center coordinate (for lightweight fetching).
    *   `boundary`: Polygon coordinates (for rendering).
*   **Flow**:
    1.  **Write**: When you conquer a cell, `TerritoryService` writes it to Firestore.
    2.  **Read**: `TerritoryRepository` listens for changes in the visible map area (Geohashing/Querying) to show *other* players' territories.

## 4. The Bottleneck (Why it hangs)
Even though data *loading* is optimized, **Rendering** is expensive.

*   **The Problem**: If you have 5,000 conquered cells, `MapView` tries to draw 5,000 individual polygons.
*   **SwiftUI Map**: Drawing thousands of overlays on the main thread is heavy.
*   **Memory**: Keeping 5,000 `TerritoryCell` objects + their UI representations in memory is taxing.

## Proposed Solution
1.  **Clustering/Simplification**: Only render cells that are visible or merge adjacent cells into larger polygons.
2.  **Limit Rendering**: Don't render *all* history on the main map, or use a lighter representation (e.g., heatmaps or dots) when zoomed out.
