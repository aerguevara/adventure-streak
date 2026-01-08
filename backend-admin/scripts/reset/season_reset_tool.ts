import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Firestore, QueryDocumentSnapshot, DocumentSnapshot, DocumentReference, WriteBatch, CollectionReference } from "firebase-admin/firestore";
import * as readline from "readline";
import { readFileSync } from "fs";

/**
 * REUSABLE SEASON RESET TOOL
 * 
 * PHASES:
 * 1. Migration & Archive: Move pre-Season data to _archive collections.
 * 2. Cleanup: Clear territories, feed, notifications, reactions.
 * 3. User Prestige & Reset: Reward prestige for old XP, reset seasonal stats.
 * 4. Reprocessing: Re-trigger activity processing for data within the new season.
 */

let DRY_RUN = false;
const BATCH_SIZE = 500;
const CONCURRENCY_LIMIT = 20;

async function main() {
    const args = process.argv.slice(2);
    const envArg = args[0]?.toUpperCase();
    const seasonId = args[1];
    const startDateStr = args[2];

    // Check for optional season name before --dry
    let seasonName = args[3];
    if (seasonName === "--dry") {
        seasonName = seasonId; // Fallback if skipped
    } else if (!seasonName) {
        seasonName = seasonId;
    }

    DRY_RUN = args.includes("--dry");

    if (!envArg || !["PRE", "PRO"].includes(envArg) || !seasonId || !startDateStr) {
        console.error("❌ Usage: npm run script scripts/reset/season_reset_tool.ts [PRE|PRO] [SeasonID] [YYYY-MM-DD] \"Season Name\" [--dry]");
        process.exit(1);
    }

    const startDate = new Date(`${startDateStr}T00:00:00Z`);
    if (isNaN(startDate.getTime())) {
        console.error("❌ Invalid date format. Use YYYY-MM-DD");
        process.exit(1);
    }

    const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";

    console.log(`\n🔥 Starting REUSABLE SEASON RESET: ${seasonId} on ${envArg} (${databaseId})`);
    console.log(`   Season Name: ${seasonName}`);
    console.log(`   Season Start: ${startDate.toISOString()}`);
    console.log(`   Mode: ${DRY_RUN ? '🌵 DRY RUN' : '🚀 LIVE EXECUTION'}\n`);

    if (envArg === "PRO" && !DRY_RUN) {
        const confirmed = await askConfirmation(`⚠️ WARNING: PRO environment. Proceed? (yes/no): `);
        if (!confirmed) process.exit(0);
    }

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
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

        // Phase 3.5: Apply Season Game Rules (Configuration)
        // CRITICAL: Must be done BEFORE reprocessing so functions use the new values.
        console.log("⚙️  Phase 3.5: Applying Season Game Rules...");
        if (!DRY_RUN) {
            const subtitleFormatter = new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" });
            const subtitle = subtitleFormatter.format(startDate);

            await db.collection("config").doc("gameplay").update({
                globalResetDate: startDate,
                currentSeasonId: seasonId,
                currentSeasonName: seasonName,
                currentSeasonSubtitle: subtitle,
                territoryExpirationDays: 7 // Update expiration to 7 days for the new season
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
            if (col.recursive) {
                await copyDocRecursive(doc, db, col.archive);
                await deleteDocRecursive(doc.ref);
            } else {
                if (!DRY_RUN) {
                    await db.collection(col.archive).doc(doc.id).set(doc.data());
                    await doc.ref.delete();
                }
            }
        });
    }
}

async function phase2Cleanup(db: Firestore, startDate: Date) {
    console.log("🧹 Phase 2: Cleanup and Map Wipe...");

    // Clear ALL territories to allow clean reconstruction
    await fastDeleteCollection(db.collection("remote_territories"));

    // Clear reactions (they will regenerate during reprocess)
    await fastDeleteCollection(db.collection("activity_reactions"));
    await fastDeleteCollection(db.collection("activity_reaction_stats"));

    // Pre-clean territories subcollections for current season activities
    const activities = await db.collection("activities").where("endDate", ">=", startDate).get();
    console.log(`   Cleaning internal state for ${activities.size} activities from current season...`);

    await runInParallel(activities.docs, async (doc) => {
        await fastDeleteSubcollection(doc.ref, "territories");
        if (!DRY_RUN) {
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

        console.log(`   User ${doc.id}: Reward ${prestigeEarned} Prestige (from ${currentXp} XP)`);

        if (!DRY_RUN) {
            const historyEntry = {
                id: seasonId, // CRITICAL: Required for Identifiable in Swift
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
                recentThieves: [],       // Clear rivals list
                recentTheftVictims: [],  // Clear victims list
                lastSeasonReset: FieldValue.serverTimestamp(),
                [`seasonHistory.${seasonId}`]: historyEntry
            });

            // CRITICAL: Delete vengeance_targets subcollection recursively
            await fastDeleteSubcollection(doc.ref, "vengeance_targets");
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
        console.log(`   Triggering: ${doc.id}...`);
        if (DRY_RUN) continue;

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

async function fastDeleteCollection(col: CollectionReference) {
    const docRefs = await col.listDocuments();
    if (docRefs.length === 0) return;
    await runInParallel(docRefs, async (docRef) => {
        await deleteDocRecursive(docRef);
    });
}

async function fastDeleteSubcollection(docRef: DocumentReference, subName: string) {
    const subCol = docRef.collection(subName);
    const docRefs = await subCol.listDocuments();
    if (docRefs.length === 0) return;
    await runInParallel(docRefs, async (subDocRef) => {
        await deleteDocRecursive(subDocRef);
    });
}

async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) {
    const chunks = chunk(items, CONCURRENCY_LIMIT);
    for (const c of chunks) {
        await Promise.all(c.map(fn));
    }
}

function chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) => array.slice(i * size, i * size + size));
}

async function setSilentMode(db: Firestore, active: boolean) {
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

async function deleteDocRecursive(docRef: DocumentReference) {
    if (DRY_RUN) return;
    const subCols = await docRef.listCollections();
    for (const sub of subCols) {
        const docRefs = await sub.listDocuments();
        await runInParallel(docRefs, async (subDocRef) => {
            await deleteDocRecursive(subDocRef);
        });
    }
    await docRef.delete();
}

async function askConfirmation(query: string): Promise<boolean> {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(query, ans => { rl.close(); resolve(ans.toLowerCase().startsWith("y")); }));
}

main().catch(console.error);
