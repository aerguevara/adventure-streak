import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentSnapshot, QueryDocumentSnapshot, Firestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

/**
 * OPTIMIZED Sync PROD -> PRE
 */

const CONCURRENCY_LIMIT = 50;

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

        const collections = await dbProd.listCollections();

        for (const colRef of collections) {
            const colName = colRef.id;
            console.log(`📦 Syncing collection: ${colName}...`);

            const docSnapshot = await colRef.get();
            if (docSnapshot.empty) continue;

            console.log(`      Found ${docSnapshot.docs.length} documents to sync in ${colName}.`);

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
        return;
    }

    // EXTRA SECURITY: Strip FCM tokens from all users except Admin (CVZ...)
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

    // Write document to target database
    await targetDb.doc(doc.ref.path).set(data);

    // List all sub-collections
    const subCollections = await doc.ref.listCollections();

    // Copy subcollections recursively
    await runInParallel(subCollections, async (subCol) => {
        const subSnapshot = await subCol.get();
        if (subSnapshot.empty) return;

        // For each document in the subcollection, recurse
        await runInParallel(subSnapshot.docs, async (subDoc) => {
            await copyDocRecursive(subDoc, targetDb);
        });
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
