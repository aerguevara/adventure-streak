import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Firestore, QueryDocumentSnapshot, DocumentSnapshot, DocumentReference, CollectionReference } from "firebase-admin/firestore";
import * as readline from "readline";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * OPTIMIZED SEASON RESET TOOL
 * 
 * PHASES:
 * 1. Migration & Archive: Move pre-Season data to _archive collections.
 * 2. Cleanup: Clear territories, feed, notifications, reactions.
 * 3. User Prestige & Reset: Reward prestige for old XP, reset seasonal stats.
 * 4. Reprocessing: Re-trigger activity processing for data within the new season.
 */

let DRY_RUN = false;
const CONCURRENCY_LIMIT = 20;

async function main() {
    const args = process.argv.slice(2);
    const envArg = args[0]?.toUpperCase();
    const seasonId = args[1];
    const startDateStr = args[2];

    let seasonName = args[3];
    if (seasonName === "--dry") {
        seasonName = seasonId;
    } else if (!seasonName) {
        seasonName = seasonId;
    }

    DRY_RUN = args.includes("--dry");

    if (!envArg || !["PRE", "PRO"].includes(envArg) || !seasonId || !startDateStr) {
        console.error("❌ Usage: npm run script scripts/season-management/season_reset_tool.ts [PRE|PRO] [SeasonID] [YYYY-MM-DD] \"Season Name\" [--dry]");
        process.exit(1);
    }

    const startDate = new Date(`${startDateStr}T00:00:00Z`);
    if (isNaN(startDate.getTime())) {
        console.error("❌ Invalid date format. Use YYYY-MM-DD");
        process.exit(1);
    }

    const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";

    console.log(`\n🔥 Starting OPTIMIZED SEASON RESET: ${seasonId} on ${envArg} (${databaseId})`);
    console.log(`   Season Name: ${seasonName}`);
    console.log(`   Season Start: ${startDate.toISOString()}`);
    console.log(`   Mode: ${DRY_RUN ? '🌵 DRY RUN' : '🚀 LIVE EXECUTION'}\n`);

    if (envArg === "PRO" && !DRY_RUN) {
        const confirmed = await askConfirmation(`⚠️ WARNING: PRO environment selected. THIS WILL MODIFY PRODUCTION DATA. Proceed? (yes/no): `);
        if (!confirmed) process.exit(0);
    }

    // Guidelines: Always initialize with Project ID and Service Account
    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    try {
        if (!DRY_RUN) await setSilentMode(db, true);

        // Phase 1: Archive old data
        await phase1Archive(db, startDate);

        // Phase 2: Cleanup world state
        await phase2Cleanup(db, startDate);

        // Phase 3: Reward Prestige and reset user counters
        await phase3UserReset(db, seasonId, seasonName, startDate);

        // Phase 3.5: Apply Season Game Rules
        console.log("⚙️  Phase 3.5: Applying Season Game Rules...");
        if (!DRY_RUN) {
            const subtitleFormatter = new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" });
            const subtitle = subtitleFormatter.format(startDate);

            await db.collection("config").doc("gameplay").update({
                globalResetDate: startDate,
                currentSeasonId: seasonId,
                currentSeasonName: seasonName,
                currentSeasonSubtitle: subtitle,
                territoryExpirationDays: 7
            });
        }

        // Phase 4: Reprocess activities in current season
        await phase4Reprocess(db, startDate);

        // Phase 5: Finalize Reset
        console.log("🏁 Phase 5: Finalizing Reset Timestamp...");
        if (!DRY_RUN) {
            await db.collection("config").doc("gameplay").update({
                lastResetAt: FieldValue.serverTimestamp()
            });
        }

        if (!DRY_RUN) {
            console.log("⏳ Waiting for processing to settle...");
            await new Promise(r => setTimeout(r, 10000));
            await setSilentMode(db, false);
        }

        console.log(`\n🏁 SEASON RESET COMPLETE.`);
    } catch (err) {
        console.error("❌ Reset failed:", err);
        if (!DRY_RUN) await setSilentMode(db, false);
        process.exit(1);
    }
}

async function phase1Archive(db: Firestore, cutOffDate: Date) {
    console.log("📁 Phase 1: Archiving pre-season data...");

    const collections = [
        { name: "activities", field: "endDate", archive: "activities_archive", recursive: true },
        { name: "feed", field: "date", archive: "feed_archive", recursive: false },
        { name: "notifications", field: "timestamp", archive: "notifications_archive", recursive: false }
    ];

    for (const col of collections) {
        console.log(`   Archiving ${col.name}...`);
        const snapshot = await db.collection(col.name).where(col.field, "<", cutOffDate).get();
        console.log(`      Found ${snapshot.size} documents.`);

        await runInParallel(snapshot.docs, async (doc) => {
            if (!DRY_RUN) {
                if (col.recursive) {
                    await copyDocRecursive(doc, db, col.archive);
                    // Standard Guideline: use recursive delete for whole collections, 
                    // but for specific docs with subcollections we still need a helper or db.recursiveDelete
                    await db.recursiveDelete(doc.ref);
                } else {
                    await db.collection(col.archive).doc(doc.id).set(doc.data());
                    await doc.ref.delete();
                }
            }
        });
    }
}

async function phase2Cleanup(db: Firestore, startDate: Date) {
    console.log("🧹 Phase 2: Cleanup and Map Wipe...");

    if (!DRY_RUN) {
        // FAST CLEAN with recursiveDelete
        await db.recursiveDelete(db.collection("remote_territories"));
        await db.recursiveDelete(db.collection("activity_reactions"));
        await db.recursiveDelete(db.collection("activity_reaction_stats"));
    }

    // Pre-clean territories subcollections for current season activities
    const activities = await db.collection("activities").where("endDate", ">=", startDate).get();
    console.log(`   Cleaning internal state for ${activities.size} activities from current season...`);

    await runInParallel(activities.docs, async (doc) => {
        if (!DRY_RUN) {
            await db.recursiveDelete(doc.ref.collection("territories"));
            await doc.ref.update({ processingStatus: FieldValue.delete() });
        }
    });
}

async function phase3UserReset(db: Firestore, seasonId: string, seasonName: string, startDate: Date) {
    console.log(`👤 Phase 3: User Prestige & Seasonal Stats Reset (Season: ${seasonName})...`);
    const users = await db.collection("users").get();

    await runInParallel(users.docs, async (doc) => {
        const data = doc.data();
        const currentXp = data.xp || 0;
        const currentCells = data.totalCellsOwned || 0;
        const prestigeEarned = Math.floor(currentXp / 5000);

        if (DRY_RUN) {
            console.log(`   [DRY] User ${doc.id}: Reward ${prestigeEarned} Prestige (from ${currentXp} XP)`);
        } else {
            const historyEntry = {
                id: seasonId,
                seasonId: seasonId,
                seasonName: seasonName,
                finalCells: currentCells,
                finalXp: currentXp,
                prestigeEarned: prestigeEarned,
                completedAt: FieldValue.serverTimestamp()
            };

            await doc.ref.update({
                prestige: FieldValue.increment(prestigeEarned),
                xp: 0,
                totalActivities: 0,
                totalDistanceKm: 0,
                totalDistanceNoGpsKm: 0,
                totalCellsOwned: 0,
                totalConqueredTerritories: 0,
                totalStolenTerritories: 0,
                totalDefendedTerritories: 0,
                totalRecapturedTerritories: 0,
                currentWeekDistanceKm: 0,
                currentWeekDistanceNoGpsKm: 0,
                currentStreakWeeks: 0,
                bestWeeklyDistanceKm: 0,
                recentTerritories: 0,
                recentThieves: [],
                recentTheftVictims: [],
                lastSeasonReset: FieldValue.serverTimestamp(),
                [`seasonHistory.${seasonId}`]: historyEntry
            });

            await db.recursiveDelete(doc.ref.collection("vengeance_targets"));
        }
    });
}

async function phase4Reprocess(db: Firestore, startDate: Date) {
    console.log("🔄 Phase 4: Retroactive Reprocessing...");

    const activities = await db.collection("activities")
        .where("endDate", ">=", startDate)
        .orderBy("endDate", "asc")
        .get();

    console.log(`   Found ${activities.size} activities to reprocess for the new season.`);

    for (const doc of activities.docs) {
        if (DRY_RUN) {
            console.log(`   [DRY] Triggering: ${doc.id}`);
            continue;
        }

        console.log(`   Triggering: ${doc.id}...`);
        await doc.ref.update({
            xpBreakdown: FieldValue.delete(),
            missions: FieldValue.delete(),
            territoryStats: FieldValue.delete(),
            processingStatus: "pending"
        });

        await waitForProcessing(doc.ref);
    }
}

/** HELPERS **/

async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) {
    const chunks = [];
    for (let i = 0; i < items.length; i += CONCURRENCY_LIMIT) {
        chunks.push(items.slice(i, i + CONCURRENCY_LIMIT));
    }
    for (const c of chunks) {
        await Promise.all(c.map(fn));
    }
}

async function setSilentMode(db: Firestore, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active} in ${db.databaseId}...`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
}

async function waitForProcessing(docRef: DocumentReference) {
    for (let i = 0; i < 300; i++) {
        const snap = await docRef.get();
        if (snap.data()?.processingStatus === "completed") return;
        await new Promise(r => setTimeout(r, 1000));
    }
}

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, db: Firestore, targetCol: string) {
    const data = doc.data();
    if (!data || DRY_RUN) return;
    await db.collection(targetCol).doc(doc.id).set(data);
    const subCols = await doc.ref.listCollections();
    for (const sub of subCols) {
        const snap = await sub.get();
        for (const sd of snap.docs) {
            await db.collection(targetCol).doc(doc.id).collection(sub.id).doc(sd.id).set(sd.data());
        }
    }
}

async function askConfirmation(query: string): Promise<boolean> {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(query, ans => { rl.close(); resolve(ans.toLowerCase().startsWith("y")); }));
}

main().catch(console.error);
