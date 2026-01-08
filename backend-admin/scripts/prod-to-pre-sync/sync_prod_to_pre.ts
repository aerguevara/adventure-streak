import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentSnapshot, QueryDocumentSnapshot, Firestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

/**
 * OPTIMIZED Sync PROD -> PRE
 */

const CONCURRENCY_LIMIT = 50;
const BATCH_SIZE = 500;

async function syncProdToPre() {
    console.log("🚀 Starting OPTIMIZED Sync PROD -> PRE...");

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const dbProd = getFirestore();
    const dbPre = getFirestore("adventure-streak-pre");

    try {
        await setSilentMode(dbPre, true);

        const collections = [
            "activities", "activity_reaction_stats", "activity_reactions",
            "config", "debug_mock_workouts", "feed", "notifications",
            "remote_territories", "reserved_icons", "users",
            "activities_archive", "feed_archive", "notifications_archive",
            "activity_reactions_archive", "remote_territories_archive"
        ];

        for (const colName of collections) {
            console.log(`📦 Syncing collection: ${colName}...`);
            const snapshot = await dbProd.collection(colName).count().get();
            const count = snapshot.data().count;
            if (count === 0) continue;

            console.log(`      Found ~${count} documents to sync.`);
            const docSnapshot = await dbProd.collection(colName).get();

            await runInParallel(docSnapshot.docs, async (doc) => {
                await copyDocRecursive(doc, dbPre);
            });
            console.log(`   ✅ Finished syncing ${colName}.`);
        }

        console.log("🏁 Sync Complete.");
    } catch (err) {
        console.error("❌ Sync failed:", err);
        process.exit(1);
    }
}

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, targetDb: any) {
    const data = doc.data();
    if (!data) return;

    // SKIP syncing 'config/maintenance' to preserve Silent Mode
    if (doc.ref.path.endsWith("config/maintenance")) {
        console.log("   🚫 Skipping config/maintenance to preserve Silent Mode.");
        return;
    }

    // EXTRA SECURITY: Strip FCM tokens from all users except Admin (CVZ...)
    // This prevents accidental notifications to real users from PRE environment
    if (doc.ref.path.startsWith("users/") && doc.ref.path.split("/").length === 2) {
        if (doc.id !== "CVZ34x99UuU6fCrOEc8Wg5nPYX82") {
            // Strip ALL token-related fields
            const sensitiveFields = [
                "fcmToken", "apnsToken",
                "fcmTokens", "apnsTokens",
                "fcmTokenUpdatedAt", "needsTokenRefresh"
            ];

            sensitiveFields.forEach(field => {
                if (data[field]) delete data[field];
            });
        }
    }

    // Async write to avoid blocking parallel execution
    await targetDb.doc(doc.ref.path).set(data);

    const subCollections = await doc.ref.listCollections();

    // Copy subcollections in parallel
    await runInParallel(subCollections, async (subCol) => {
        const subSnapshot = await subCol.get();
        if (subSnapshot.empty) return;

        const chunks = chunk(subSnapshot.docs, BATCH_SIZE);
        for (const batchDocs of chunks) {
            const batch = targetDb.batch();
            batchDocs.forEach(sd => {
                batch.set(targetDb.doc(sd.ref.path), sd.data());
            });
            await batch.commit();
        }
    });
}

async function setSilentMode(db: any, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active} in ${db.databaseId}...`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
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

syncProdToPre().catch(err => {
    console.error("❌ Sync failed:", err);
    process.exit(1);
});
