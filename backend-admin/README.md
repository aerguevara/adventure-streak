# Adventure Streak Backend Admin Tools

This directory contains administrative scripts and tools for managing the Adventure Streak platform, performing data maintenance, and simulating scenarios for testing.

## Directory Structure

- `scripts/maintenance/`: Scripts for data cleanup, backfilling missing info, and fixing inconsistencies.
- `scripts/sync/`: Tools for synchronizing data between different environments (e.g., PROD to PRE).
- `scripts/reset/`: Scripts for major database resets and era transitions (like the Dec 2025 reset).
- `scripts/analysis/`: Audits, global searches, and data exploration tools.
- `scripts/testing/`: Scenario setups, simulation helpers, and verification tests.
- `scripts/legacy/`: Archived scripts kept for historical reference.

## Prerequisites

- Node.js installed.
- Firebase Service Account key (requested by scripts at runtime or configured via environment variables).

## Installation

```bash
cd backend-admin
npm install
```

## Running Scripts

You can run JavaScript (`.js`) and TypeScript (`.ts`) scripts using `npm run script`.

### Running a TypeScript Script
```bash
npm run script scripts/maintenance/backfill_feed.ts
```

### Running a JavaScript Script
```bash
node scripts/analysis/audit_xp.js
```

---

## Tool Categories

### 🧹 Maintenance
- `backfill_feed.ts`: standardizes location labels in the feed.
- `fix_user_pre.ts`: fixes specific user state in the PRE environment.
- `cleanup_workouts.js`: removes orphaned or invalid workout data.

### 🔄 Sync & Reset
- `sync_prod_to_pre.ts`: Synchronizes a subset of production data to the PRE database.
- `reset_dec_2025.ts`: The official script for the December 2025 "New Era" reset.
- `clear_pre_database.ts`: Wipes the PRE database (use with caution).

### 🔍 Analysis & Audits
- `audit_xp.js`: Analyzes XP distribution and identifies anomalies.
- `check_pre_state.ts`: Verifies the consistency of the PRE database.
- `global_search.js`: Searches for specific strings across all collections.

### 🧪 Testing & Scenarios
- `scripts/testing/scenarios/`: A collection of scripts to setup specific map scenarios (Hotspots, Expiring territories, etc.).
- `simulate_defense_workout.js`: Simulates a workout that triggers a territory defense.
- `verify_full_reset.ts`: Validates that a reset was performed correctly.

## Disclaimer
These tools perform direct database operations. **Always verify the target environment** before execution.
