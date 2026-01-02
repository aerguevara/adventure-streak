# Adventure Streak Simulations

This directory contains logic for "High Fidelity Simulations".

## Philosophy: "Real Processing, Real Results"

Instead of manually manipulating `remote_territories` or user stats in Firestore (which is error-prone and doesn't test the actual business logic), we use **Activity Cloning**.

### How it works:
1.  **Select a Source Activity**: Pick a real, valid activity from PROD (or history) that contains the route/territories you want to test (e.g., a specific conquest route).
2.  **Clone & Assign**: The script duplicates this activity's metadata and subcollections (routes/territories) but assigns it to a **Test User** (e.g., Simulator User).
3.  **Trigger Native Processing**: The script uploads the activity with `processingStatus: 'uploading'` and then immediately updates it to `processingStatus: 'pending'`.
4.  **Cloud Function Does the Work**: The standard `processActivityCompletePRE` Cloud Function picks up the change, calculates intersections, handles territory theft/conquest, updates stats, and sends notifications.

### Benefits:
*   **Tests the entire pipeline**: Verifies triggers, physics engine, gamification rules, and notifications.
*   **Reproducible**: You can re-run the same "Perfect Theft" or "Perfect Defense" scenario 100 times.
*   **Clean Data**: Keeps the database consistent because the server is the one writing the final state.

## Available Scripts

### `clone_and_steal.ts`
Simulates a territory theft by cloning a known "Conquest" activity (`EF8B...`) and assigning it to the Simulator User.
*   **Usage**: `npm run script scripts/simulations/clone_and_steal.ts`
*   **Target**: Steals territory `-1817_20224` (Calle de Juan Ignacio Luca de Tena).
