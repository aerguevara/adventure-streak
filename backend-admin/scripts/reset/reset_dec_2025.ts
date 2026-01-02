import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Firestore, QueryDocumentSnapshot, DocumentSnapshot, DocumentReference, WriteBatch, CollectionReference } from "firebase-admin/firestore";
import * as readline from "readline";
import { readFileSync } from "fs";

/**
 * RESET DEC 2025 SCRIPT (OPTIMIZED)
 * 
 * PHASES:
 * 1. Migration & Archive: Move pre-Dec 1st data to _archive collections.
 * 2. Total Cleanup: Clear territories, feed, notifications, reactions.
 * 3. User Reset: Initial stats (Level 1, 0 XP, etc.)
 * 4. Reprocessing: Re-trigger activity processing sequentially for post-Dec 1st data.
 */

let DRY_RUN = false;
const BATCH_SIZE = 500;
const CONCURRENCY_LIMIT = 20;

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

    console.log(`\n🔥 Starting OPTIMIZED RESET DEC 2025 on ${envArg} (${databaseId})`);
    console.log(`   Phase: ${targetPhase ? `Phase ${targetPhase}` : 'ALL PHASES'}`);
    console.log(`   Mode: ${DRY_RUN ? '🌵 DRY RUN' : '🚀 LIVE EXECUTION'}\n`);

    if (envArg === "PRO" && !DRY_RUN) {
        const confirmed = await askConfirmation(`⚠️ WARNING: PRO environment. Proceed? (yes/no): `);
        if (!confirmed) process.exit(0);
    }

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore(databaseId);
    const cutOffDate = new Date("2025-12-01T00:00:00Z");

    try {
        if (!DRY_RUN) await setSilentMode(db, true);

        if (!targetPhase || targetPhase === 1) await phase1Archive(db, cutOffDate);
        if (!targetPhase || targetPhase === 2) await phase2Cleanup(db);
        if (!targetPhase || targetPhase === 3) await phase3UserReset(db);
        if (!targetPhase || targetPhase === 4) {
            await phase4Reprocess(db, cutOffDate);
            if (!DRY_RUN) {
                console.log("⏳ Waiting 10s for background tasks to settle before disabling Silent Mode...");
                await new Promise(r => setTimeout(r, 10000));
                await setSilentMode(db, false);
            }
        }

        console.log(`\n🏁 RESET COMPLETE.`);
    } catch (err) {
        console.error("❌ Reset failed:", err);
        if (!DRY_RUN) await setSilentMode(db, false);
        process.exit(1);
    }
}

async function phase1Archive(db: Firestore, cutOffDate: Date) {
    console.log("📁 Phase 1: Parallel Archiving...");

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

async function phase2Cleanup(db: Firestore) {
    console.log("🧹 Phase 2: Total Cleanup (Batched)...");
    const collections = ["remote_territories", "feed", "notifications", "activity_reactions", "activity_reaction_stats"];
    for (const col of collections) {
        await fastDeleteCollection(db.collection(col));
    }

    // New: Pre-clean territories subcollections for ALL post-cutoff activities
    console.log("   Pre-cleaning territories from all activities...");
    const cutOffDate = new Date("2025-12-01T00:00:00Z");
    const activities = await db.collection("activities").where("endDate", ">=", cutOffDate).get();
    console.log(`      Found ${activities.size} activities to clean sub-collections.`);

    await runInParallel(activities.docs, async (doc) => {
        await fastDeleteSubcollection(doc.ref, "territories");
        // Clear processing status to un-stick pending activities
        if (!DRY_RUN) {
            await doc.ref.update({
                processingStatus: FieldValue.delete()
            });
        }
    });
}

async function phase3UserReset(db: Firestore) {
    console.log("👤 Phase 3: User Reset (Batched)...");
    const users = await db.collection("users").get();
    const chunks = chunk(users.docs, BATCH_SIZE);

    for (const batchDocs of chunks) {
        if (DRY_RUN) {
            console.log(`   🌵 [DRY RUN] Would reset ${batchDocs.length} users`);
            continue;
        }
        const batch = db.batch();
        batchDocs.forEach(doc => {
            batch.update(doc.ref, {
                xp: 0, level: 1, totalConqueredTerritories: 0, totalStolenTerritories: 0,
                totalDefendedTerritories: 0, totalRecapturedTerritories: 0, totalCellsOwned: 0,
                recentTerritories: 0, currentWeekDistanceKm: 0, bestWeeklyDistanceKm: 0,
                currentStreakWeeks: 0, prestige: 0, hasAcknowledgedDecReset: false,
                recentThieves: [], lastActivityDate: FieldValue.delete()
            });
        });
        await batch.commit();
    }
}

async function phase4Reprocess(db: Firestore, cutOffDate: Date) {
    console.log("🔄 Phase 4: Sequential Reprocessing (Pure Triggering)...");
    await adjustLookbackConfiguration(db, cutOffDate);

    const activities = await db.collection("activities")
        .where("endDate", ">=", cutOffDate)
        .orderBy("endDate", "asc")
        .get();

    console.log(`   Found ${activities.size} activities to reprocess.`);
    let count = 0;
    for (const doc of activities.docs) {
        count++;
        console.log(`   [${count}/${activities.size}] Triggering: ${doc.id}...`);
        if (DRY_RUN) continue;

        // 1. Trigger reprocessing (Territories are already cleaned in Phase 2)
        await doc.ref.update({
            xpBreakdown: FieldValue.delete(),
            missions: FieldValue.delete(),
            territoryStats: FieldValue.delete(),
            conqueredVictims: FieldValue.delete(),
            processingStatus: "pending"
        });

        // 2. STRICT WAIT
        await waitForProcessing(doc.ref);
        await markActivityNotificationsAsRead(db, doc.id);
    }
}

/** HELPERS **/

async function fastDeleteCollection(col: CollectionReference) {
    console.log(`   Clearing ${col.path} (Deep Recursive)...`);
    const docRefs = await col.listDocuments();
    if (docRefs.length === 0) return;

    console.log(`      Found ${docRefs.length} document references.`);
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
    console.log(`🔧 Silent Mode -> ${active}`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
}

async function waitForProcessing(docRef: DocumentReference) {
    for (let i = 0; i < 300; i++) {
        const snap = await docRef.get();
        if (snap.data()?.processingStatus === "completed") return;
        await new Promise(r => setTimeout(r, 1000));
    }
    console.warn(`      ⚠️ Timeout: ${docRef.id}`);
}

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, db: Firestore, targetCol: string) {
    const data = doc.data();
    if (!data || DRY_RUN) return;
    await db.collection(targetCol).doc(doc.id).set(data);
    const subCols = await doc.ref.listCollections();
    for (const sub of subCols) {
        const snap = await sub.get();
        const batchSize = 500;
        const subChunks = chunk(snap.docs, batchSize);
        for (const batchDocs of subChunks) {
            const batch = db.batch();
            batchDocs.forEach(sd => batch.set(db.collection(targetCol).doc(doc.id).collection(sub.id).doc(sd.id), sd.data()));
            await batch.commit();
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

async function markActivityNotificationsAsRead(db: Firestore, activityId: string) {
    const snaps = await db.collection("notifications").where("activityId", "==", activityId).get();
    if (snaps.empty || DRY_RUN) return;
    const batch = db.batch();
    snaps.docs.forEach(d => batch.update(d.ref, { isRead: true }));
    await batch.commit();
}

async function adjustLookbackConfiguration(db: Firestore, cutOffDate: Date) {
    const diffDays = Math.floor(Math.abs(Date.now() - cutOffDate.getTime()) / (1000 * 60 * 60 * 24));
    if (DRY_RUN) return;
    await db.collection("config").doc("gameplay").update({ workoutLookbackDays: diffDays });
}

async function askConfirmation(query: string): Promise<boolean> {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(query, ans => { rl.close(); resolve(ans.toLowerCase().startsWith("y")); }));
}

main().catch(console.error);
