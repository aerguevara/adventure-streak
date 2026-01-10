import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentSnapshot, QueryDocumentSnapshot, Firestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * OPTIMIZED Sync PROD -> PRE
 * Focuses on maintaining GUIDELINES and SECURITY.
 */

const CONCURRENCY_LIMIT = 50;
const BATCH_SIZE = 500;

async function syncProdToPre() {
    console.log("🚀 Starting OPTIMIZED Sync PROD -> PRE...");

    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const dbProd = getFirestore(); // Default is PRO (adventure-streak)
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

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, targetDb: Firestore) {
    const data = doc.data();
    if (!data) return;

    // SKIP syncing 'config/maintenance' to preserve Silent Mode settings in PRE
    if (doc.ref.path.endsWith("config/maintenance")) {
        return;
    }

    // SECURITY: Strip FCM tokens from all users except Admin
    if (doc.ref.path.startsWith("users/") && doc.ref.path.split("/").length === 2) {
        if (doc.id !== "CVZ34x99UuU6fCrOEc8Wg5nPYX82") {
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

    // Set document in target
    await targetDb.doc(doc.ref.path).set(data);

    // Subcollections
    const subCollections = await doc.ref.listCollections();
    for (const subCol of subCollections) {
        const subSnapshot = await subCol.get();
        if (subSnapshot.empty) continue;

        const docs = subSnapshot.docs;
        for (let i = 0; i < docs.length; i += BATCH_SIZE) {
            const chunk = docs.slice(i, i + BATCH_SIZE);
            const batch = targetDb.batch();
            chunk.forEach(sd => {
                batch.set(targetDb.doc(sd.ref.path), sd.data());
            });
            await batch.commit();
        }
    }
}

async function setSilentMode(db: Firestore, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active} in ${db.databaseId}...`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
}

async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) {
    for (let i = 0; i < items.length; i += CONCURRENCY_LIMIT) {
        const chunk = items.slice(i, i + CONCURRENCY_LIMIT);
        await Promise.all(chunk.map(fn));
    }
}

syncProdToPre().catch(err => {
    console.error("❌ Sync failed:", err);
    process.exit(1);
});
