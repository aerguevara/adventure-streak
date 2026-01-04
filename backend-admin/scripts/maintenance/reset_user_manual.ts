import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Firestore, DocumentReference, CollectionReference } from "firebase-admin/firestore";
import { readFileSync } from "fs";

/**
 * MANUAL USER RESET SCRIPT
 * 
 * Target User: jq779GJi5cZvmXnH33n2w0AXHMw1
 * Database: adventure-streak-pre
 * 
 * ACTIONS:
 * 1. Delete all activities + routes + territories sub-collections.
 * 2. Delete all remote_territories owned by the user.
 * 3. Delete all feed events by the user.
 * 4. Delete all notifications sent to or from the user.
 * 5. Reset user stats (XP, level, counts) to initial state.
 */

const TARGET_USER_ID = "jq779GJi5cZvmXnH33n2w0AXHMw1";
const args = process.argv.slice(2);
const envArg = args.find(a => ["PRE", "PRO"].includes(a.toUpperCase()))?.toUpperCase() || "PRE";
const DRY_RUN = !args.includes("--live");
const BATCH_SIZE = 500;

async function main() {
    const databaseId = envArg === "PRO" ? "(default)" : "adventure-streak-pre";
    console.log(`\n🔥 Starting MANUAL RESET for User: ${TARGET_USER_ID}`);
    console.log(`   Environment: ${envArg} (${databaseId})`);
    console.log(`   Mode: ${DRY_RUN ? '🌵 DRY RUN (Use --live for actual execution)' : '🚀 LIVE EXECUTION'}\n`);

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore(databaseId);

    try {
        // 1. Activities & Subcollections
        console.log("📂 Step 1: Deleting Activities & Subcollections...");
        const activitySnaps = await db.collection("activities").where("userId", "==", TARGET_USER_ID).get();
        console.log(`   Found ${activitySnaps.size} activities.`);

        for (const doc of activitySnaps.docs) {
            console.log(`      - Deleting Activity ${doc.id}`);
            if (!DRY_RUN) {
                await deleteDocRecursive(doc.ref);
            }
        }

        // 2. Remote Territories
        console.log("🌍 Step 2: Deleting Remote Territories...");
        const territoriesQ = db.collection("remote_territories").where("userId", "==", TARGET_USER_ID);
        const territoriesSnap = await territoriesQ.get();
        console.log(`   Found ${territoriesSnap.size} owned cells.`);
        if (!DRY_RUN) {
            await deleteQuery(db, territoriesQ);
        }

        // 3. Feed
        console.log("📝 Step 3: Deleting Feed Items...");
        const feedQ = db.collection("feed").where("userId", "==", TARGET_USER_ID);
        const feedSnap = await feedQ.get();
        console.log(`   Found ${feedSnap.size} feed items.`);
        if (!DRY_RUN) {
            await deleteQuery(db, feedQ);
        }

        // 4. Notifications
        console.log("🔔 Step 4: Deleting Notifications...");
        const notifRecipientQ = db.collection("notifications").where("recipientId", "==", TARGET_USER_ID);
        const notifSenderQ = db.collection("notifications").where("senderId", "==", TARGET_USER_ID);
        const recipientSnap = await notifRecipientQ.get();
        const senderSnap = await notifSenderQ.get();
        console.log(`   Found ${recipientSnap.size} received and ${senderSnap.size} sent notifications.`);
        if (!DRY_RUN) {
            await deleteQuery(db, notifRecipientQ);
            await deleteQuery(db, notifSenderQ);
        }

        // 5. User Reset
        console.log("👤 Step 5: Resetting User Stats...");
        const userRef = db.collection("users").doc(TARGET_USER_ID);
        const userSnap = await userRef.get();
        if (userSnap.exists) {
            if (DRY_RUN) {
                console.log(`   🌵 [DRY RUN] Would reset stats for user ${TARGET_USER_ID}`);
            } else {
                await userRef.update({
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
                    recentThieves: [],
                    lastActivityDate: FieldValue.delete()
                });
                console.log(`   ✅ User stats reset.`);
            }
        } else {
            console.warn(`   ⚠️ User ${TARGET_USER_ID} not found in Firestore.`);
        }

        console.log(`\n🏁 ${DRY_RUN ? 'DRY RUN COMPLETE' : 'RESET COMPLETE'}.`);
    } catch (err) {
        console.error("❌ Reset failed:", err);
    }
}

/** HELPERS **/

async function deleteQuery(db: Firestore, query: FirebaseFirestore.Query) {
    const snapshot = await query.get();
    if (snapshot.empty) return;

    const chunks = chunk(snapshot.docs, BATCH_SIZE);
    for (const batchDocs of chunks) {
        const batch = db.batch();
        batchDocs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
    }
}

async function deleteDocRecursive(docRef: DocumentReference) {
    const subCols = await docRef.listCollections();
    for (const sub of subCols) {
        const docRefs = await sub.listDocuments();
        const chunks = chunk(docRefs, BATCH_SIZE);
        for (const batchDocs of chunks) {
            const batch = docRef.firestore.batch();
            batchDocs.forEach(ref => batch.delete(ref));
            await batch.commit();
        }
    }
    await docRef.delete();
}

function chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) => array.slice(i * size, i * size + size));
}

main().catch(console.error);
