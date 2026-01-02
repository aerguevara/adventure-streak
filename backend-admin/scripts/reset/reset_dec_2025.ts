import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Firestore, QueryDocumentSnapshot, DocumentSnapshot, DocumentReference, WriteBatch } from "firebase-admin/firestore";
import * as readline from "readline";
import { readFileSync } from "fs";

/**
 * RESET DEC 2025 SCRIPT
 * 
 * PHASES:
 * 1. Migration & Archive: Move pre-Dec 1st data to _archive collections.
 * 2. Total Cleanup: Clear territories, feed, notifications, reactions.
 * 3. User Reset: Initial stats (Level 1, 0 XP, etc.)
 * 4. Reprocessing: Re-trigger activity processing sequentially for post-Dec 1st data.
 * 
 * USAGE:
 * npm run script scripts/reset/reset_dec_2025.ts [env: PRE|PRO] [phase: 1-4] [--dry]
 */

let DRY_RUN = false;

async function main() {
    const args = process.argv.slice(2);
    const envArg = args[0]?.toUpperCase();
    const phaseArg = args[1];
    DRY_RUN = args.includes("--dry");

    if (!envArg || !["PRE", "PRO"].includes(envArg)) {
        console.error("❌ Usage: npm run script scripts/reset/reset_dec_2025.ts [PRE|PRO] [phase] [--dry]");
        process.exit(1);
    }

    const targetPhase = phaseArg && !phaseArg.startsWith("--") ? parseInt(phaseArg) : null;
    const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";

    console.log(`\n🔥 Starting RESET DEC 2025 on ${envArg} (${databaseId})`);
    console.log(`   Phase: ${targetPhase ? `Phase ${targetPhase}` : 'ALL PHASES'}`);
    console.log(`   Mode: ${DRY_RUN ? '🌵 DRY RUN (No changes will be made)' : '🚀 LIVE EXECUTION'}\n`);

    if (envArg === "PRO" && !DRY_RUN) {
        const confirmed = await askConfirmation(`⚠️ WARNING: You are targeting PRO environment. Are you sure? (yes/no): `);
        if (!confirmed) {
            console.log("❌ Aborted by user.");
            process.exit(0);
        }
    }

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);
    const cutOffDate = new Date("2025-12-01T00:00:00Z");

    try {
        // ALWAYS enable Silent Mode at the start for safety (unless dry run)
        if (!DRY_RUN) {
            await setSilentMode(db, true);
        } else {
            console.log("🌵 [DRY RUN] Would set Silent Mode to true");
        }

        if (!targetPhase || targetPhase === 1) {
            await phase1Archive(db, cutOffDate);
        }

        if (!targetPhase || targetPhase === 2) {
            await phase2Cleanup(db);
        }

        if (!targetPhase || targetPhase === 3) {
            await phase3UserReset(db);
        }

        if (!targetPhase || targetPhase === 4) {
            await phase4Reprocess(db, cutOffDate);
            if (!DRY_RUN) {
                await setSilentMode(db, false);
            } else {
                console.log("🌵 [DRY RUN] Would set Silent Mode to false");
            }
        }

        console.log(`\n🏁 RESET DEC 2025 - ${targetPhase ? `PHASE ${targetPhase}` : 'ALL PHASES'} COMPLETE.`);
    } catch (err) {
        console.error("❌ Reset failed:", err);
        if (!DRY_RUN) {
            await setSilentMode(db, false);
        }
        process.exit(1);
    }
}

function askConfirmation(query: string): Promise<boolean> {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    return new Promise(resolve => rl.question(query, ans => {
        rl.close();
        resolve(ans.toLowerCase() === "yes" || ans.toLowerCase() === "y");
    }));
}

async function setSilentMode(db: Firestore, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active}...`);
    if (DRY_RUN) {
        console.log(`   🌵 [DRY RUN] Would update config/maintenance -> { silentMode: ${active} }`);
        return;
    }
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
}

async function phase1Archive(db: Firestore, cutOffDate: Date) {
    console.log("📁 Phase 1: Archiving pre-Dec 1st data...");

    // 1. Activities
    console.log("   Archiving activities...");
    const activities = await db.collection("activities").where("endDate", "<", cutOffDate).get();
    console.log(`      Found ${activities.size} activities to archive.`);
    for (const doc of activities.docs) {
        await copyDocRecursive(doc, db, "activities_archive");
        await deleteDocRecursive(doc.ref);
    }

    // 2. Feed
    console.log("   Archiving feed events...");
    const feed = await db.collection("feed").where("date", "<", cutOffDate).get();
    console.log(`      Found ${feed.size} feed events to archive.`);
    for (const doc of feed.docs) {
        if (!DRY_RUN) {
            await db.collection("feed_archive").doc(doc.id).set(doc.data());
            await doc.ref.delete();
        } else {
            console.log(`      🌵 [DRY RUN] Would archive & delete feed event: ${doc.id}`);
        }
    }

    // 3. Notifications
    console.log("   Archiving notifications...");
    const notifications = await db.collection("notifications").where("timestamp", "<", cutOffDate).get();
    console.log(`      Found ${notifications.size} notifications to archive.`);
    for (const doc of notifications.docs) {
        if (!DRY_RUN) {
            await db.collection("notifications_archive").doc(doc.id).set(doc.data());
            await doc.ref.delete();
        } else {
            console.log(`      🌵 [DRY RUN] Would archive & delete notification: ${doc.id}`);
        }
    }
}

async function phase2Cleanup(db: Firestore) {
    console.log("扫 Phase 2: Total Cleanup...");

    const collectionsToClear = [
        "remote_territories",
        "feed",
        "notifications",
        "activity_reactions",
        "activity_reaction_stats"
    ];

    for (const colName of collectionsToClear) {
        console.log(`   Clearing ${colName}...`);
        const snapshot = await db.collection(colName).get();
        console.log(`      Found ${snapshot.size} documents to delete.`);
        for (const doc of snapshot.docs) {
            await deleteDocRecursive(doc.ref);
        }
    }
}

async function phase3UserReset(db: Firestore) {
    console.log("👤 Phase 3: User Reset (Tabula Rasa)...");
    const users = await db.collection("users").get();
    console.log(`   Resetting ${users.size} users.`);
    for (const doc of users.docs) {
        const updateData = {
            xp: 0,
            level: 1,
            totalConqueredTerritories: 0,
            totalStolenTerritories: 0,
            totalDefendedTerritories: 0,
            totalRecapturedTerritories: 0,
            totalCellsOwned: 0,
            recentTerritories: 0,
            currentWeekDistanceKm: 0,
            bestWeeklyDistanceKm: 0,
            currentStreakWeeks: 0,
            prestige: 0,
            hasAcknowledgedDecReset: false,
            recentTheftVictims: [],
            recentThieves: [],
            lastActivityDate: FieldValue.delete()
        };
        if (!DRY_RUN) {
            await doc.ref.update(updateData);
        } else {
            console.log(`   🌵 [DRY RUN] Would reset stats for user: ${doc.id}`);
        }
    }
}

async function phase4Reprocess(db: Firestore, cutOffDate: Date) {
    console.log("🔄 Phase 4: Reprocessing activities...");

    // 0. Adjust Configuration Dynamically
    await adjustLookbackConfiguration(db, cutOffDate);

    const activities = await db.collection("activities")
        .where("endDate", ">=", cutOffDate)
        .orderBy("endDate", "asc")
        .get();

    console.log(`   Found ${activities.size} activities to reprocess.`);
    for (const doc of activities.docs) {
        const activityId = doc.id;
        const info = doc.data();
        console.log(`   Reprocessing activity: ${activityId} (Date: ${info.endDate?.toDate()?.toISOString() || 'N/A'})...`);

        if (DRY_RUN) {
            console.log(`      🌵 [DRY RUN] Would reprocess activity: ${activityId}`);
            continue;
        }

        // 1. Reset activity territories subcollection
        const territories = await doc.ref.collection("territories").get();
        for (const tDoc of territories.docs) {
            await tDoc.ref.delete();
        }

        // 2. Clear computed stats and trigger reprocessing
        await doc.ref.update({
            xpBreakdown: FieldValue.delete(),
            missions: FieldValue.delete(),
            territoryStats: FieldValue.delete(),
            conqueredVictims: FieldValue.delete(),
            processingStatus: "pending"
        });

        // 3. WAIT for processing (poll every 1s, max 30s)
        await waitForProcessing(doc.ref);

        // 4. Mark generated notifications as read (SILENT MODE)
        await markActivityNotificationsAsRead(db, activityId);
    }
}

async function markActivityNotificationsAsRead(db: Firestore, activityId: string) {
    const notifications = await db.collection("notifications").where("activityId", "==", activityId).get();
    if (notifications.empty) return;

    console.log(`      🧹 Marking ${notifications.size} notifications as read...`);
    if (DRY_RUN) {
        console.log(`      🌵 [DRY RUN] Would mark ${notifications.size} notifications as read.`);
        return;
    }
    const batch = db.batch();
    notifications.docs.forEach(doc => {
        batch.update(doc.ref, { isRead: true });
    });
    await batch.commit();
}

async function waitForProcessing(docRef: DocumentReference) {
    const maxAttempts = 90; // Increased to 90s to avoid timeouts on heavy activities
    for (let i = 0; i < maxAttempts; i++) {
        const snap = await docRef.get();
        const status = snap.data()?.processingStatus;
        if (status === "completed") {
            console.log(`      ✓ Completed.`);
            return;
        }
        await new Promise(r => setTimeout(r, 1000));
    }
    console.warn(`      ⚠️ Timeout waiting for activity ${docRef.id}`);
}

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, db: Firestore, targetCollection: string) {
    const data = doc.data();
    if (!data) return;

    if (DRY_RUN) {
        console.log(`      🌵 [DRY RUN] Would copy doc ${doc.id} to ${targetCollection}`);
    } else {
        await db.collection(targetCollection).doc(doc.id).set(data);
    }

    const subCols = await doc.ref.listCollections();
    for (const subCol of subCols) {
        const subSnapshot = await subCol.get();
        for (const subDoc of subSnapshot.docs) {
            if (DRY_RUN) {
                console.log(`         🌵 [DRY RUN] Would copy subdoc ${subDoc.id} from ${subCol.id}`);
            } else {
                await db.collection(targetCollection).doc(doc.id).collection(subCol.id).doc(subDoc.id).set(subDoc.data());
            }
        }
    }
}

async function deleteDocRecursive(docRef: DocumentReference) {
    const subCols = await docRef.listCollections();
    for (const subCol of subCols) {
        const subSnapshot = await subCol.get();
        for (const subDoc of subSnapshot.docs) {
            await deleteDocRecursive(subDoc.ref);
        }
    }
    if (DRY_RUN) {
        console.log(`      🌵 [DRY RUN] Would delete doc: ${docRef.path}`);
    } else {
        await docRef.delete();
    }
}


async function adjustLookbackConfiguration(db: Firestore, cutOffDate: Date) {
    console.log("   ⚙️ Adjusting 'workoutLookbackDays' configuration...");
    const now = new Date();

    // Calculate days difference (rounding down to stay strictly within the limit)
    const diffTime = Math.abs(now.getTime() - cutOffDate.getTime());
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    console.log(`      Current Date: ${now.toISOString().split('T')[0]}`);
    console.log(`      Cutoff Date: ${cutOffDate.toISOString().split('T')[0]}`);
    console.log(`      Calculated Lookback: ${diffDays} days`);

    if (diffDays < 0) {
        console.warn("      ⚠️ Cutoff date is in the future? Skipping adjustment.");
        return;
    }

    if (DRY_RUN) {
        console.log(`      🌵 [DRY RUN] Would update config/gameplay -> { workoutLookbackDays: ${diffDays} }`);
        return;
    }

    await db.collection("config").doc("gameplay").update({
        workoutLookbackDays: diffDays
    });
    console.log(`      ✅ Updated 'workoutLookbackDays' to ${diffDays}.`);
}

main().catch(console.error);
